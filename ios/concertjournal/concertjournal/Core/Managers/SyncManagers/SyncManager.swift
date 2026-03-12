//
//  SyncManager.swift
//  concertjournal
//

import CoreData
import Foundation
import Combine
import Auth

class SyncManager {

    let coreData = CoreDataStack.shared
    var isSyncing = false
    let apiClient: BFFClient

    private let userSessionManager: UserSessionManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()

    init(apiClient: BFFClient,
         userSessionManager: UserSessionManagerProtocol) {
        self.apiClient = apiClient
        self.userSessionManager = userSessionManager
    }

    // MARK: - Auth Check

    /// Prüft, ob der User eingeloggt ist.
    /// Alle Sync-Operationen sollten diese Methode zuerst aufrufen.
    private var isLoggedIn: Bool {
        if case .loggedIn = userSessionManager.state {
            return true
        }
        return false
    }

    // MARK: - Full Sync

    func fullSync() async throws {
        guard isLoggedIn else {
            logDebug("Skip sync – user not logged in", category: .sync)
            return
        }

        guard !isSyncing else {
            logDebug("Sync already in progress", category: .sync)
            return
        }

        isSyncing = true
        NotificationCenter.default.post(name: .syncInProgress, object: true)

        await resetOldErrorStates()
        

        logInfo("Starting full sync", category: .sync)

        do {
            try await pullChanges()
            try await pushChanges()
        } catch {
            NotificationCenter.default.post(name: .syncInProgress, object: false)
            throw error
        }
        logSuccess("Full sync completed", category: .sync)
        
        isSyncing = false
        NotificationCenter.default.post(name: .syncInProgress, object: false)
    }

    func resetOldErrorStates() async {
        let context = coreData.newBackgroundContext()

        await context.perform {
            let request: NSFetchRequest<Concert> = Concert.fetchRequest()
            request.predicate = NSPredicate(
                format: "syncStatus IN %@",
                [SyncStatus.error.rawValue]
            )

            for concert in (try? context.fetch(request)) ?? [] {
                concert.syncStatus = SyncStatus.pending.rawValue
            }
            try? context.save()
        }
    }

    // MARK: - Individual Concert Sync

    func syncConcert(_ concert: Concert) async {
        guard isLoggedIn else {
            logDebug("Skip concert sync – user not logged in", category: .sync)
            return
        }

        let id = concert.objectID
        let context = coreData.newBackgroundContext()
        await context.perform {
            guard let bgConcert = try? context.existingObject(with: id) as? Concert else {
                return
            }

            switch bgConcert.syncStatus {
            case SyncStatus.pending.rawValue:
                Task { try? await self.pushSingleConcert(objectID: bgConcert.objectID) }
            case SyncStatus.deleted.rawValue:
                Task { try? await self.deleteConcertOnServer(objectID: bgConcert.objectID) }
            default:
                break
            }
        }
    }

    // MARK: - Pull (Server → Core Data)

    private func pullChanges() async throws {
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? .distantPast

        struct PullResponse: Codable {
            let concerts: [ServerConcert]
            let deleted: [String]
        }

        let response: PullResponse = try await apiClient.get(
            "/sync/concerts?since=\(lastSyncDate.ISO8601Format())"
        )

        let context = coreData.newBackgroundContext()

        // Merges außerhalb von context.perform awaiten
        var problems: [SyncingProblem] = []
        var pulledConcerts = 0

        for serverConcert in response.concerts {
            do {
                let problem = try await mergeConcertFromServerSync(serverConcert, context: context)
                if let problem {
                    problems.append(problem)
                    pulledConcerts += 1
                } else {
                    pulledConcerts += 1
                }
            } catch {
                logError("Failed to pull concert", error: error)
            }
        }

        await context.perform {
            for deletedId in response.deleted {
                self.deleteConcertFromServerSync(deletedId, context: context)
            }
            if context.hasChanges {
                try? context.save()
            }
        }

        if !problems.isEmpty {
            await MainActor.run {
                NotificationCenter.default.post(name: .syncingProblem, object: nil)
            }
        }

        logSuccess("Pulled \(pulledConcerts) concerts", category: .sync)
        
        if pulledConcerts > 0 {
            coreData.didChange.send()
        }

        guard pulledConcerts == response.concerts.count else { return }
        
        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        }
    }
    // MARK: - Push (Core Data → Server)

    private func pushChanges() async throws {
        let context = coreData.newBackgroundContext()

        let pendingIds: [ConcertSyncInfo] = await context.perform {
            let request: NSFetchRequest<Concert> = Concert.fetchRequest()
            request.predicate = NSPredicate(
                format: "syncStatus IN %@",
                [SyncStatus.pending.rawValue, SyncStatus.deleted.rawValue]
            )

            let concerts = try? context.fetch(request)
            return concerts?.map { concert in
                ConcertSyncInfo(
                    objectID: concert.objectID,
                    syncStatus: concert.syncStatus ?? "",
                    serverId: concert.serverId
                )
            } ?? []
        }

        logInfo("Attemptimg to push \(pendingIds.count) changes", category: .sync)

        for info in pendingIds {
            if info.syncStatus == SyncStatus.deleted.rawValue {
                try await deleteConcertOnServer(objectID: info.objectID)
            } else {
                try await pushSingleConcert(objectID: info.objectID)
            }
        }

        logSuccess("Pushed \(pendingIds.count) changes", category: .sync)
    }

    private func pushSingleConcert(objectID: NSManagedObjectID) async throws {
        let context = coreData.newBackgroundContext()

        let payload = await context.perform { () -> ConcertPushPayload? in
            guard let concert = try? context.existingObject(with: objectID) as? Concert else {
                return nil
            }
            return ConcertPushPayload(concert: concert)
        }

        guard var payload else { return }
        
        if payload.artistServerId == nil {
            logInfo("Concert in sync has artist \"\(payload.artist.name)\" which does not exist on the server", category: .sync)
            logInfo("Creating \"\(payload.artist.name)\"", category: .sync)
            let serverArtist: ArtistDTO = try await apiClient.post("/artists", body: CreateArtistDTO(artist: payload.artist))
            logSuccess("Successfully created \"\(payload.artist.name)\"", category: .sync)
            payload.artistServerId = serverArtist.id
            
            await context.perform {
                let request: NSFetchRequest<Artist> = Artist.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND serverId == nil", payload.artist.name)
                request.fetchLimit = 1
                if let localArtist = try? context.fetch(request).first {
                    localArtist.serverId = serverArtist.id
                    localArtist.syncStatus = SyncStatus.synced.rawValue
                    try? context.save()
                }
            }
        }
        if let venue = payload.venue, payload.venueServerId == nil {
            logInfo("Concert in sync has venue \"\(venue.name)\" which does not exist on the server", category: .sync)
            logInfo("Creating \"\(venue.name)\"", category: .sync)
            let serverVenue: IDResponse = try await apiClient.post("/venues", body: venue)
            logSuccess("Successfully created \"\(venue.name)\"", category: .sync)
            payload.venueServerId = serverVenue.id
            
            await context.perform {
                let request: NSFetchRequest<Venue> = Venue.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND serverId == nil", venue.name)
                request.fetchLimit = 1
                if let localVenue = try? context.fetch(request).first {
                    localVenue.serverId = serverVenue.id
                    localVenue.syncStatus = SyncStatus.synced.rawValue
                    try? context.save()
                }
            }
        }
        if payload.supportActServerIds?.count != payload.supportActs?.count {
            logInfo("Concert in sync has support acts \"\(payload.supportActs?.map { $0.name } ?? [])\" which do not exist on the server", category: .sync)
            logInfo("Creating \"\(payload.supportActs?.map { $0.name } ?? [])\"", category: .sync)
            var supportActsIds = [String]()
            for artist in payload.supportActs ?? [] {
                let serverArtist: ArtistDTO = try await apiClient.post("/artists", body: CreateArtistDTO(artist: artist))
                supportActsIds.append(serverArtist.id)
                
                await context.perform {
                    let request: NSFetchRequest<Artist> = Artist.fetchRequest()
                    request.predicate = NSPredicate(format: "name == %@ AND serverId == nil", artist.name)
                    request.fetchLimit = 1
                    if let localArtist = try? context.fetch(request).first {
                        localArtist.serverId = serverArtist.id
                        localArtist.syncStatus = SyncStatus.synced.rawValue
                        try? context.save()
                    }
                }
            }
            logSuccess("Successfully created \"\(payload.supportActs?.map { $0.name } ?? [])\"", category: .sync)

            payload.supportActServerIds = supportActsIds
        }

        if let tour = payload.tour, payload.tourServerId == nil {
            logInfo("Concert in sync has Tour \"\(tour.name)\" which does not exist on the server", category: .sync)
            logInfo("Creating \"\(tour.name)\"", category: .sync)

            let serverTour: IDResponse = try await apiClient.post("/tours", body: tour)
            logSuccess("Successfully created \"\(tour.name)\"", category: .sync)
            payload.tourServerId = serverTour.id

            await context.perform {
                let request: NSFetchRequest<Tour> = Tour.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND serverId == nil", tour.name)
                request.fetchLimit = 1

                if let localTour = try? context.fetch(request).first {
                    localTour.serverId = serverTour.id
                    localTour.syncStatus = SyncStatus.synced.rawValue
                    try? context.save()
                }
            }
        }

        // ENCRYPTION
        payload.title = try CredentialEncryption.shared.encryptWithCredentials(payload.title)
        if let notes = payload.notes {
            payload.notes = try CredentialEncryption.shared.encryptWithCredentials(notes)
        }
        if let ticketNotes = payload.ticketNotes {
            payload.ticketNotes = try CredentialEncryption.shared.encryptWithCredentials(ticketNotes)
        }

        if let serverId = payload.serverId {
            // Update
            logInfo("Updating Concert \"\(serverId)\"", category: .sync)
            let _: ServerConcert = try await apiClient.put("/sync/concerts/\(serverId)", body: payload)
        } else {
            logInfo("Creating Concert \"\(payload.title ?? payload.artist.name)\"", category: .sync)
            // Create

            let response: ServerConcert = try await apiClient.post("/sync/concerts", body: payload)
            await context.perform {
                if let concert = try? context.existingObject(with: objectID) as? Concert {
                    concert.serverId = response.id
                    concert.syncStatus = SyncStatus.synced.rawValue
                    concert.lastSyncedAt = Date()
                    try? context.save()
                }
            }
        }

        await context.perform {
            if let concert = try? context.existingObject(with: objectID) as? Concert {
                concert.syncStatus = SyncStatus.synced.rawValue
                concert.lastSyncedAt = Date()
                try? context.save()
            }
        }
    }

    private func deleteConcertOnServer(objectID: NSManagedObjectID) async throws {
        let context = coreData.newBackgroundContext()

        let serverId = await context.perform { () -> String? in
            guard let concert = try? context.existingObject(with: objectID) as? Concert else {
                return nil
            }
            return concert.serverId
        }

        if let serverId {
            try await apiClient.delete("/sync/concerts/\(serverId)")
        }

        await context.perform {
            if let concert = try? context.existingObject(with: objectID) as? Concert {
                context.delete(concert)
                try? context.save()
            }
        }
    }

    // MARK: - Merge (upsert)

    private func mergeConcertFromServerSync(_ serverConcert: ServerConcert, context: NSManagedObjectContext) async throws -> SyncingProblem? {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverConcert.id)
        request.fetchLimit = 1

        if let existing = try context.fetch(request).first {
            return await updateConcertSync(existing, with: serverConcert, context: context)
        } else {
            return await createConcertSync(serverConcert, context: context)
        }
    }

    private func deleteConcertFromServerSync(_ serverId: String, context: NSManagedObjectContext) {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        guard let concert = try? context.fetch(request).first else { return }
        context.delete(concert)
    }

    // MARK: - Update existing Concert

    private func updateConcertSync(_ concert: Concert, with server: ServerConcert, context: NSManagedObjectContext) async -> SyncingProblem? {
        if concert.syncStatus == SyncStatus.pending.rawValue,
           let serverModified = server.updatedAt,
           let localModified = concert.locallyModifiedAt,
           localModified > serverModified {
            concert.syncStatus = SyncStatus.conflict.rawValue
            logWarning("Conflict for: \(concert.title ?? "?")", category: .sync)
            return nil
        }

        var problem: SyncingProblem? = nil
        do {
            if let title = server.title {
                if let decrypted = try? CredentialEncryption.shared.decryptWithCredentials(title) {
                    concert.title = decrypted
                } else {
                    concert.title = String.randomGibberish(length: 12) + " Entschlüsselung Fehlgeschlagen"
                    problem = SyncingProblem.decryptionFailed
                }
            }
            if let notes = server.notes {
                if let decrypted = try? CredentialEncryption.shared.decryptWithCredentials(notes) {
                    concert.notes   = decrypted
                } else {
                    concert.notes = String.randomGibberish(length: 20) + "\nEntschlüsselung Fehlgeschlagen"
                    problem = SyncingProblem.decryptionFailed
                }
            }
            concert.date        = server.date
            concert.openingTime = server.openingTime
            concert.rating      = Int16(server.rating ?? 0)
            concert.city        = server.city
            
            concert.setBuddies(server.buddyAttendees ?? [])

            if let artistId = server.artistId {
                concert.artist = try await fetchOrCreateArtistSync(serverId: artistId, context: context)
            }
            
            if let venueId = server.venueId {
                concert.venue = try await fetchOrCreateVenueSync(serverId: venueId, context: context)
            } else {
                concert.venue = nil
            }

            if let tourId = server.tourId {
                concert.tour = try await fetchOrCreateTourSync(serverId: tourId, context: context)
            }

            concert.travel = buildTravelSync(from: server, existing: concert.travel, context: context)
            let (ticket, ticketProblem) = try buildTicketSync(from: server, existing: concert.ticket, context: context)
            concert.ticket = ticket
            problem = ticketProblem
            try await updateSupportActsSync(concert: concert, serverIds: server.supportActsIds ?? [], context: context)
            
            concert.serverModifiedAt = server.updatedAt
            concert.syncStatus       = SyncStatus.synced.rawValue
            concert.lastSyncedAt     = Date()
            
            return problem
        } catch {
            logError("Could not sync concert", error: error)
            return nil
        }
    }

    // MARK: - Create new Concert

    private func createConcertSync(_ server: ServerConcert, context: NSManagedObjectContext) async -> SyncingProblem? {
        let concert = Concert(context: context)
        concert.id       = UUID()
        concert.serverId = server.id

        concert.date        = server.date
        concert.openingTime = server.openingTime
        concert.rating      = Int16(server.rating ?? 0)
        concert.city        = server.city

        var problem: SyncingProblem? = nil
        do {
            if let title = server.title {
                if let decrypted = try? CredentialEncryption.shared.decryptWithCredentials(title) {
                    concert.title   = decrypted
                } else {
                    concert.title = String.randomGibberish(length: 12) + " Entschlüsselung Fehlgeschlagen"
                    problem = SyncingProblem.decryptionFailed
                }
            }
            if let notes = server.notes {
                if let decrypted = try? CredentialEncryption.shared.decryptWithCredentials(notes) {
                    concert.notes   = decrypted
                } else {
                    concert.notes = String.randomGibberish(length: 20) + "\nEntschlüsselung Fehlgeschlagen"
                    problem = SyncingProblem.decryptionFailed
                }
            }

            if let artistId = server.artistId {
                concert.artist = try await fetchOrCreateArtistSync(serverId: artistId, context: context)
            }
            
            if let venueId = server.venueId {
                concert.venue = try await fetchOrCreateVenueSync(serverId: venueId, context: context)
            }
            
            try await updateSupportActsSync(concert: concert, serverIds: server.supportActsIds ?? [], context: context)
            
            concert.setBuddies(server.buddyAttendees ?? [])
            concert.travel = buildTravelSync(from: server, existing: nil, context: context)
            let (ticket, ticketProblem) = try buildTicketSync(from: server, existing: nil, context: context)
            concert.ticket = ticket
            problem = ticketProblem

            if let tourId = server.tourId {
                concert.tour = try await fetchOrCreateTourSync(serverId: tourId, context: context)
            }

            let currentUserId = await getCurrentUserId()
            concert.ownerId  = server.userId
            concert.isOwner  = server.userId == currentUserId
            concert.canEdit  = concert.isOwner
            
            concert.syncStatus        = SyncStatus.synced.rawValue
            concert.lastSyncedAt      = Date()
            concert.serverModifiedAt  = server.updatedAt
            concert.locallyModifiedAt = Date()
            concert.syncVersion       = 1
            
            return problem
        } catch {
            logError("Could not sync concert", error: error)
            return nil
        }
    }

    // MARK: - Travel Builder

    private func buildTravelSync(
        from server: ServerConcert,
        existing: Travel?,
        context: NSManagedObjectContext
    ) -> Travel? {
        guard server.travelType != nil
                || server.travelDuration != nil
                || server.travelDistance != nil
                || server.arrivedAt != nil
                || server.travelExpenses != nil
                || server.hotelExpenses != nil
        else {
            if let old = existing { context.delete(old) }
            return nil
        }

        let travel = existing ?? Travel(context: context)
        travel.travelType     = server.travelType
        travel.travelDuration = server.travelDuration ?? 0
        travel.travelDistance = server.travelDistance ?? 0
        travel.arrivedAt      = server.arrivedAt

        if let travelExpenses = server.travelExpenses {
            travel.travelExpensesValue = NSDecimalNumber(decimal: travelExpenses.value)
            travel.travelExpensesCurrency = travelExpenses.currency
        }
        if let hotelExpenses = server.hotelExpenses {
            travel.hotelExpensesValue = NSDecimalNumber(decimal: hotelExpenses.value)
            travel.hotelExpensesCurrency = hotelExpenses.currency
        }

        return travel
    }

    // MARK: - Ticket Builder

    private func buildTicketSync(
        from server: ServerConcert,
        existing: Ticket?,
        context: NSManagedObjectContext
    ) throws -> (Ticket?, SyncingProblem?) {
        guard server.ticketType != nil
                || server.ticketCategory != nil
                || server.seatBlock != nil
        else {
            if let old = existing { context.delete(old) }
            return (nil, nil)
        }

        var problem: SyncingProblem? = nil
        let ticket = existing ?? Ticket(context: context)
        ticket.ticketType       = server.ticketType ?? TicketType.standing.rawValue
        ticket.ticketCategory   = server.ticketCategory ?? TicketCategory.regular.rawValue
        ticket.seatBlock        = server.seatBlock
        ticket.seatRow          = server.seatRow
        ticket.seatNumber       = server.seatNumber
        ticket.standingPosition = server.standingPosition
        if let ticketNotes = server.ticketNotes {
            if let decrypted = try? CredentialEncryption.shared.decryptWithCredentials(ticketNotes) {
                ticket.notes    = decrypted
            } else {
                ticket.notes = String.randomGibberish(length: 12) + "\nEntschlüsselung Fehlgeschlagen"
                problem = SyncingProblem.decryptionFailed
            }
        }

        if let ticketPrice = server.ticketPrice {
            ticket.ticketPriceValue = NSDecimalNumber(decimal: ticketPrice.value)
            ticket.ticketPriceCurrency = ticketPrice.currency
        }

        return (ticket, problem)
    }

    // MARK: - Support Acts Sync

    private func updateSupportActsSync(
        concert: Concert,
        serverIds: [String],
        context: NSManagedObjectContext
    ) async throws {
        (concert.supportActs as? Set<Artist>)?.forEach { concert.removeSupportAct($0) }

        for serverId in serverIds {
            let artist = try await fetchOrCreateArtistSync(serverId: serverId, context: context)
            concert.addSupportAct(artist)
        }
    }

    // MARK: - Helpers

    func getCurrentUserId() async -> String {
        // Direkt aus Supabase Session holen – kein UserDefaults nötig
        do {
            return try await userSessionManager.loadUser().id.uuidString.lowercased()
        } catch {
            return "unknown"
        }
    }
}
