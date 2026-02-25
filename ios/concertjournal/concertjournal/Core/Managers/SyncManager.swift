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

    func deduplicateArtists() async {
        let context = coreData.newBackgroundContext()
        await context.perform {
            let request: NSFetchRequest<Artist> = Artist.fetchRequest()
            guard let all = try? context.fetch(request) else { return }

            var seen: [String: Artist] = [:]  // spotifyId → erster Artist

            for artist in all {
                guard let spotifyId = artist.spotifyArtistId, !spotifyId.isEmpty else { continue }

                if let existing = seen[spotifyId] {
                    // Duplikat: Concerts ummappen und dann löschen
                    (artist.concerts as? Set<Concert>)?.forEach {
                        $0.artist = existing
                    }
                    context.delete(artist)
                } else {
                    seen[spotifyId] = artist
                }
            }
            try? context.save()
        }
    }

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
        defer { isSyncing = false }

        await resetOldErrorStates()
        

        logInfo("Starting full sync", category: .sync)

        await deduplicateArtists()
        try await pullChanges()
        try await pushChanges()

        logSuccess("Full sync completed", category: .sync)
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
        payload.title = try ConcertEncryptionHelper.shared.encrypt(payload.title)
        if let notes = payload.notes {
            payload.notes = try ConcertEncryptionHelper.shared.encrypt(notes)
        }
        if let ticketNotes = payload.ticketNotes {
            payload.ticketNotes = try ConcertEncryptionHelper.shared.encrypt(ticketNotes)
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
                if let decrypted = try? ConcertEncryptionHelper.shared.decrypt(title) {
                    concert.title   = decrypted
                } else {
                    problem = SyncingProblem.decryptionFailed
                }
            }
            if let notes = server.notes {
                if let decrypted = try? ConcertEncryptionHelper.shared.decrypt(notes) {
                    concert.notes   = decrypted
                } else {
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
                if let decrypted = try? ConcertEncryptionHelper.shared.decrypt(title) {
                    concert.title   = decrypted
                } else {
                    problem = SyncingProblem.decryptionFailed
                }
            }
            if let notes = server.notes {
                if let decrypted = try? ConcertEncryptionHelper.shared.decrypt(notes) {
                    concert.notes   = decrypted
                } else {
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
            if let decrypted = try? ConcertEncryptionHelper.shared.decrypt(ticketNotes) {
                ticket.notes    = decrypted
            } else {
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

    // MARK: - Tour Sync

    private func fetchOrCreateTourSync(serverId: String, context: NSManagedObjectContext) async throws -> Tour {
        let request: NSFetchRequest<Tour> = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let loadedTour: TourDTO = try await apiClient.get("/tours/\(serverId)")

        let tour = Tour(context: context)
        tour.id = UUID()
        tour.serverId = serverId
        tour.syncStatus = SyncStatus.synced.rawValue

        tour.name = loadedTour.name
        tour.artist = try await fetchOrCreateArtistSync(serverId: loadedTour.artistId, context: context)

        // TODO: FIX
        tour.startDate = loadedTour.startDate.supabaseStringDate ?? Date.now
        tour.endDate = loadedTour.endDate.supabaseStringDate ?? Date.now
        tour.tourDescription = loadedTour.tourDescription

        let currentUserId = await getCurrentUserId()
        tour.ownerId = loadedTour.ownerId
        tour.isOwner = loadedTour.ownerId == currentUserId
        tour.lastSyncedAt = Date.now
        tour.locallyModifiedAt = nil
        tour.syncVersion = 1

        return tour
    }

    // MARK: - Artist Sync

    private func fetchOrCreateArtistSync(serverId: String, context: NSManagedObjectContext) async throws -> Artist {
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let loadedArtist: ArtistDTO = try await apiClient.get("/artists/\(serverId)")

        let artist = Artist(context: context)
        artist.id = UUID()
        artist.serverId = serverId
        artist.syncStatus = SyncStatus.synced.rawValue

        artist.name = loadedArtist.name
        artist.imageUrl = loadedArtist.imageUrl
        artist.spotifyArtistId = loadedArtist.spotifyArtistId
        
        return artist
    }

    // MARK: - Venue Sync

    private func fetchOrCreateVenueSync(serverId: String, context: NSManagedObjectContext) async throws -> Venue {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let loadedVenue: VenueDTO = try await apiClient.get("/venues/\(serverId)")

        let venue = Venue(context: context)
        venue.id = UUID()
        venue.serverId = serverId
        venue.syncStatus = SyncStatus.synced.rawValue

        venue.name = loadedVenue.name
        venue.city = loadedVenue.city
        venue.formattedAddress = loadedVenue.formattedAddress
        venue.latitude = loadedVenue.latitude ?? 0
        venue.longitude = loadedVenue.longitude ?? 0
        venue.appleMapsId = loadedVenue.appleMapsId
        
        return venue
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

// MARK: - Push Payload

struct ConcertPushPayload: Encodable {
    let serverId: String?
    var title: String?
    let date: Date
    let openingTime: Date?
    var notes: String?
    let rating: Int?
    let city: String?
    let version: Int
    var buddyAttendees: [BuddyAttendee]

    let artist: ArtistDTO
    var artistServerId: String?
    var venueServerId: String?
    let venue: VenueDTO?
    var supportActServerIds: [String]?
    let supportActs: [ArtistDTO]?

    var tourServerId: String?
    let tour: TourDTO?

    let travelType: String?
    let travelDuration: Double?
    let travelDistance: Double?
    let arrivedAt: Date?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?

    let ticketType: String?
    let ticketCategory: String?
    let ticketPrice: PriceDTO?
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?
    let standingPosition: String?
    var ticketNotes: String?

    private enum CodingKeys: String, CodingKey {
        case date, city, notes, rating, title, version
        case buddyAttendees = "buddy_attendees"
        case serverId = "id"
        case venueServerId = "venue_id"
        case artistServerId = "artist_id"
        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
        case ticketPrice = "ticket_price"
        case openingTime = "opening_time"
        case arrivedAt = "arrived_at"
        case tourId = "tour_id"
        case supportActServerIds = "support_acts_ids"
    }

    init(concert: Concert) {
        serverId    = concert.serverId
        title       = concert.title
        date        = concert.date
        openingTime = concert.openingTime
        notes       = concert.notes
        rating      = concert.rating == 0 ? nil : Int(concert.rating)
        city        = concert.city
        version     = Int(concert.syncVersion)
        buddyAttendees = concert.buddiesArray

        artistServerId  = concert.artist.serverId
        artist = concert.artist.toDTO()
        venueServerId   = concert.venue?.serverId
        venue = concert.venue?.toDTO()

        supportActs = concert.supportActsArray.compactMap { $0.toDTO() }
        supportActServerIds = concert.supportActsArray
            .compactMap { $0.serverId }

        tour = concert.tour?.toDTO()
        tourServerId = concert.tour?.serverId

        travelType     = concert.travel?.travelType
        travelDuration = concert.travel?.travelDuration
        travelDistance = concert.travel?.travelDistance
        arrivedAt      = concert.travel?.arrivedAt
        travelExpenses = concert.travel?.travelExpenses
        hotelExpenses = concert.travel?.hotelExpenses

        ticketType     = concert.ticket?.ticketType
        ticketCategory = concert.ticket?.ticketCategory
        seatBlock      = concert.ticket?.seatBlock
        seatRow        = concert.ticket?.seatRow
        seatNumber     = concert.ticket?.seatNumber
        standingPosition = concert.ticket?.standingPosition
        ticketNotes    = concert.ticket?.notes
        ticketPrice    = concert.ticket?.ticketPrice
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.serverId, forKey: .serverId)
        try container.encode(self.date.supabseDateString, forKey: .date)
        try container.encodeIfPresent(self.city, forKey: .city)
        try container.encodeIfPresent(self.notes, forKey: .notes)
        try container.encodeIfPresent(self.rating, forKey: .rating)
        try container.encodeIfPresent(self.title, forKey: .title)
        try container.encode(self.version, forKey: .version)
        try container.encodeIfPresent(self.buddyAttendees, forKey: .buddyAttendees)
        try container.encodeIfPresent(self.venueServerId, forKey: .venueServerId)
        try container.encodeIfPresent(self.artistServerId, forKey: .artistServerId)
        try container.encodeIfPresent(self.travelType, forKey: .travelType)
        try container.encodeIfPresent(self.travelDuration, forKey: .travelDuration)
        try container.encodeIfPresent(self.travelDistance, forKey: .travelDistance)
        try container.encodeIfPresent(self.travelExpenses, forKey: .travelExpenses)
        try container.encodeIfPresent(self.hotelExpenses, forKey: .hotelExpenses)
        try container.encodeIfPresent(self.ticketType, forKey: .ticketType)
        try container.encodeIfPresent(self.ticketCategory, forKey: .ticketCategory)
        try container.encodeIfPresent(self.seatBlock, forKey: .seatBlock)
        try container.encodeIfPresent(self.seatRow, forKey: .seatRow)
        try container.encodeIfPresent(self.seatNumber, forKey: .seatNumber)
        try container.encodeIfPresent(self.standingPosition, forKey: .standingPosition)
        try container.encodeIfPresent(self.ticketNotes, forKey: .ticketNotes)
        try container.encodeIfPresent(self.ticketPrice, forKey: .ticketPrice)
        try container.encodeIfPresent(self.openingTime?.supabseDateString, forKey: .openingTime)
        try container.encodeIfPresent(self.arrivedAt?.supabseDateString, forKey: .arrivedAt)
        try container.encodeIfPresent(self.tourServerId, forKey: .tourId)
        try container.encodeIfPresent(self.supportActServerIds, forKey: .supportActServerIds)
    }
}

// MARK: - Sync Helper Structs

struct ConcertSyncInfo {
    let objectID: NSManagedObjectID
    let syncStatus: String
    let serverId: String?
}

// MARK: - Errors

enum SyncError: Error {
    case missingServerId
    case UploadFailedFor(String)
    case contextMismatch
}

// MARK: - Server Models

struct ServerConcert: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date?
    let userId: String
    let artistId: String?
    let date: Date
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    let buddyAttendees: [BuddyAttendee]?
    let venueId: String?
    let travelType: String?
    let travelDuration: Double?
    let travelDistance: Double?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?
    let ticketType: String?
    let ticketCategory: String?
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?
    let standingPosition: String?
    let ticketNotes: String?
    let ticketPrice: PriceDTO?
    let openingTime: Date?
    let arrivedAt: Date?
    let tourId: String?
    let supportActsIds: [String]?
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, date, city, notes, rating, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case artistId = "artist_id"
        case venueId = "venue_id"
        case buddyAttendees = "buddy_attendees"
        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
        case ticketPrice = "ticket_price"
        case openingTime = "opening_time"
        case arrivedAt = "arrived_at"
        case tourId = "tour_id"
        case supportActsIds = "support_acts_ids"
        case deletedAt = "deleted_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        self.buddyAttendees = try container.decodeIfPresent([BuddyAttendee].self, forKey: .buddyAttendees)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.venueId = try container.decodeIfPresent(String.self, forKey: .venueId)
        self.travelType = try container.decodeIfPresent(String.self, forKey: .travelType)
        self.travelDuration = try container.decodeIfPresent(Double.self, forKey: .travelDuration)
        self.travelDistance = try container.decodeIfPresent(Double.self, forKey: .travelDistance)
        self.travelExpenses = try container.decodeIfPresent(PriceDTO.self, forKey: .travelExpenses)
        self.hotelExpenses = try container.decodeIfPresent(PriceDTO.self, forKey: .hotelExpenses)
        self.ticketType = try container.decodeIfPresent(String.self, forKey: .ticketType)
        self.ticketCategory = try container.decodeIfPresent(String.self, forKey: .ticketCategory)
        self.seatBlock = try container.decodeIfPresent(String.self, forKey: .seatBlock)
        self.seatRow = try container.decodeIfPresent(String.self, forKey: .seatRow)
        self.seatNumber = try container.decodeIfPresent(String.self, forKey: .seatNumber)
        self.standingPosition = try container.decodeIfPresent(String.self, forKey: .standingPosition)
        self.ticketNotes = try container.decodeIfPresent(String.self, forKey: .ticketNotes)
        self.ticketPrice = try container.decodeIfPresent(PriceDTO.self, forKey: .ticketPrice)
        self.supportActsIds = try container.decodeIfPresent([String].self, forKey: .supportActsIds)
        self.tourId = try container.decodeIfPresent(String.self, forKey: .tourId)

        if let createdAt = try container.decode(String.self, forKey: .createdAt).supabaseStringDate {
            self.createdAt = createdAt
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.createdAt], debugDescription: "Created at missing"))
        }
        if let updatedAt = try container.decode(String.self, forKey: .updatedAt).supabaseStringDate {
            self.updatedAt = updatedAt
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.updatedAt], debugDescription: "Updated at missing"))
        }
        if let date = try container.decode(String.self, forKey: .date).supabaseStringDate {
            self.date = date
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.updatedAt], debugDescription: "Date at missing"))
        }
        if let openingTime = try container.decodeIfPresent(String.self, forKey: .openingTime)?.supabaseStringDate {
            self.openingTime = openingTime
        } else {
            self.openingTime = nil
        }
        if let arrivedAt = try container.decodeIfPresent(String.self, forKey: .arrivedAt)?.supabaseStringDate {
            self.arrivedAt = arrivedAt
        } else {
            self.arrivedAt = nil
        }
        if let deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)?.supabaseStringDate {
            self.deletedAt = deletedAt
        } else {
            self.deletedAt = nil
        }
    }
}

enum SyncingProblem {
    case decryptionFailed
}
