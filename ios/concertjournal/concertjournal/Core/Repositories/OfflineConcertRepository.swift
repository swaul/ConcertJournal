//
//  OfflineConcertRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import CoreData
import Combine
import WidgetKit
import Auth

protocol OfflineConcertRepositoryProtocol {
    func fetchConcerts() -> [Concert]
    func fetchConcertsWithArtist(_ id: UUID) -> [Concert]
    func getConcert(id: UUID) -> Concert?
    func createConcert(_ dto: CreateConcertDTO) async throws -> NSManagedObjectID
    func updateConcert(_ concertId: NSManagedObjectID, with dto: ConcertUpdate) async throws
    func deleteConcert(_ concertId: NSManagedObjectID) throws
    func presaveArtist(_ newArtist: ArtistDTO) throws -> Artist
    func sync() async throws
}

class OfflineConcertRepository: OfflineConcertRepositoryProtocol {

    private let coreData = CoreDataStack.shared
    private let syncManager: SyncManager
    private let userSessionManager: UserSessionManagerProtocol

    init(syncManager: SyncManager, userSessionManager: UserSessionManagerProtocol) {
        self.syncManager = syncManager
        self.userSessionManager = userSessionManager
    }

    // MARK: - Fetch (Always from Core Data)

    func fetchConcerts() -> [Concert] {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Only show non-deleted concerts
        request.predicate = NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue)

        // Sort by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching concerts: \(error)")
            return []
        }
    }

    func fetchConcertsWithArtist(_ id: UUID) -> [Concert] {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Only show non-deleted concerts
        request.predicate = NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue)

        // Sort by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        do {
            return try context.fetch(request).filter { $0.artist.id == id }
        } catch {
            print("Error fetching concerts: \(error)")
            return []
        }
    }

    func getConcert(id: UUID) -> Concert? {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching concert: \(error)")
            return nil
        }
    }

    // MARK: - Create (Local First)

    func createConcert(_ dto: CreateConcertDTO) async throws -> NSManagedObjectID {
        let context = coreData.viewContext

        // 1. Create in Core Data
        let concert = Concert(context: context)
        concert.id = dto.id
        concert.title = dto.title
        concert.date = dto.date
        concert.notes = dto.notes
        concert.rating = Int16(dto.rating ?? 0)
        concert.city = dto.city

        // Set sync metadata
        concert.syncStatus = SyncStatus.pending.rawValue
        concert.locallyModifiedAt = Date()
        concert.syncVersion = 1
        concert.ownerId = await getCurrentUserId()
        concert.isOwner = true
        concert.canEdit = true

        // Artist & Venue
        concert.artist = await fetchOrCreateArtist(from: dto.artist, context: context)

        if let venue = dto.venue {
            concert.venue = await fetchOrCreateVenue(from: venue, context: context)
        }

        // Support Acts
        for actDTO in dto.supportActs {
            let act = await fetchOrCreateArtist(from: actDTO, context: context)
            concert.addSupportAct(act)
        }

        // Setlist
        for item in dto.setlistItems {
            let setlistItem = buildSetlistItem(from: item, concertId: concert.id.uuidString.lowercased(), context: context)
            concert.addSetlistItem(setlistItem)
        }
        // Travel
        if let travelDTO = dto.travel {
            concert.travel = buildTravel(from: travelDTO, context: context)
        }

        // Ticket
        if let ticketDTO = dto.ticket {
            concert.ticket = buildTicket(from: ticketDTO, context: context)
        }

        // 2. Save to Core Data
        try coreData.saveWithResult()

        WidgetCenter.shared.reloadAllTimelines()

        // 3. Queue for sync
        Task {
            await syncManager.syncConcert(concert)
        }

        return concert.objectID
    }

    // MARK: - Update (Local First)

    func updateConcert(_ concertId: NSManagedObjectID, with dto: ConcertUpdate) async throws {
        let context = coreData.viewContext
        let concert: Concert = context.object(with: concertId) as! Concert

        // Check permission
        guard concert.canEdit else {
            throw RepositoryError.noPermission
        }

        // 1. Update in Core Data
        if let title = dto.title {
            concert.title = title
        }

        concert.date        = dto.date
        concert.openingTime = dto.openingTime
        concert.city        = dto.city ?? concert.city

        if let notes = dto.notes {
            concert.notes = notes
        }

        if let rating = dto.rating {
            concert.rating = Int16(rating)
        }

        // Venue
        if let venueDTO = dto.venue {
            concert.venue = await fetchOrCreateVenue(from: venueDTO, context: context)
        }
        
        if let buddies = dto.buddyAttendees {
            concert.setBuddies(buddies)
        }

        // Support Acts: alte entfernen, neue setzen
        if let newActs = dto.supportActs {
            (concert.supportActs as? Set<Artist>)?.forEach { concert.removeSupportAct($0) }
            for actDTO in newActs {
                concert.addSupportAct(await fetchOrCreateArtist(from: actDTO, context: context))
            }
        }

        if let setlistItems = dto.setlistItems {
            for item in setlistItems {
                let setlistItem = buildSetlistItem(from: item, concertId: concert.id.uuidString.lowercased(), context: context)
                concert.addSetlistItem(setlistItem)
            }
        }

        // Travel: altes löschen und neu aufbauen
        if let travelDTO = dto.travel {
            if let old = concert.travel { context.delete(old) }
            concert.travel = buildTravel(from: travelDTO, context: context)
        }

        // Ticket: altes löschen und neu aufbauen
        if let ticketDTO = dto.ticket {
            if let old = concert.ticket { context.delete(old) }
            concert.ticket = buildTicket(from: ticketDTO, context: context)
        }

        // Update sync metadata
        concert.syncStatus = SyncStatus.pending.rawValue
        concert.locallyModifiedAt = Date()
        concert.syncVersion += 1

        // 2. Save to Core Data
        try coreData.saveWithResult()

        WidgetCenter.shared.reloadAllTimelines() // ← neu

        // 3. Queue for sync
        Task {
            await syncManager.syncConcert(concert)
        }
    }

    func presaveArtist(_ newArtist: ArtistDTO) throws -> Artist {
        let context = coreData.viewContext

        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", newArtist.id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let artist = Artist(context: context)
        artist.id = UUID()
        artist.name = newArtist.name
        artist.spotifyArtistId = newArtist.spotifyArtistId
        artist.imageUrl = newArtist.imageUrl

        // 2. Save to Core Data
        try coreData.saveWithResult()

        return artist
    }

    // MARK: - Delete (Soft Delete)

    func deleteConcert(_ concertId: NSManagedObjectID) throws {
        let context = coreData.viewContext
        let concert = context.object(with: concertId) as! Concert

        // Check permission
        guard concert.canEdit else {
            throw RepositoryError.noPermission
        }

        // 1. Mark as deleted (soft delete)
        concert.syncStatus = SyncStatus.deleted.rawValue
        concert.locallyModifiedAt = Date()

        // 2. Save
        try coreData.saveWithResult()

        WidgetCenter.shared.reloadAllTimelines()

        // 3. Queue for sync (will delete on server)
        Task {
            await syncManager.syncConcert(concert)
        }
    }

    // MARK: - Sync

    func sync() async throws {
        try await syncManager.fullSync()
    }

    // MARK: - Helpers
    private func fetchOrCreateArtist(
        from dto: ArtistDTO,
        context: NSManagedObjectContext
    ) async -> Artist {

        // 1. Server fragen via spotifyId
        if let spotifyId = dto.spotifyArtistId, !spotifyId.isEmpty {
            if let serverArtist: ArtistDTO = try? await syncManager.apiClient.get("/artists/\(spotifyId)") {
                // Server kennt ihn – lokal nach serverId suchen oder neu anlegen
                if let existing = fetchLocalArtistIfExists(serverArtist: serverArtist, context: context) {
                    return existing
                }

                // Server kennt ihn aber lokal noch nicht → mit serverId anlegen
                let artist = Artist(context: context)
                artist.id = UUID()
                artist.name = serverArtist.name
                artist.imageUrl = serverArtist.imageUrl
                artist.spotifyArtistId = serverArtist.spotifyArtistId
                artist.serverId = serverArtist.id  // ← direkt mit serverId
                artist.syncStatus = SyncStatus.synced.rawValue  // ← schon synced!
                return artist
            }
        }

        // 2. Lokal nach spotifyId suchen (Server offline oder kein spotifyId)
        if let spotifyId = dto.spotifyArtistId, !spotifyId.isEmpty {
            let request: NSFetchRequest<Artist> = Artist.fetchRequest()
            request.predicate = NSPredicate(format: "spotifyArtistId == %@", spotifyId)
            request.fetchLimit = 1
            if let existing = try? context.fetch(request).first {
                return existing
            }
        }

        // 3. Neu anlegen (wirklich unbekannt)
        let artist = Artist(context: context)
        artist.id = UUID()
        artist.name = dto.name
        artist.imageUrl = dto.imageUrl
        artist.spotifyArtistId = dto.spotifyArtistId
        artist.syncStatus = SyncStatus.pending.rawValue
        return artist
    }

    private func fetchLocalArtistIfExists(serverArtist: ArtistDTO, context: NSManagedObjectContext) -> Artist? {
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverArtist.id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        guard let spotifyId = serverArtist.spotifyArtistId, !spotifyId.isEmpty else { return nil }
        request.predicate = NSPredicate(format: "spotifyArtistId == %@", spotifyId)

        if let existing = try? context.fetch(request).first {
            existing.serverId = serverArtist.id
            existing.syncStatus = SyncStatus.synced.rawValue
            return existing
        }

        return nil
    }

    private func fetchOrCreateVenue(
        from dto: VenueDTO,
        context: NSManagedObjectContext
    ) async -> Venue {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()

        if let appleMapsId = dto.appleMapsId, !appleMapsId.isEmpty {
            if let serverVenue: VenueDTO = try? await syncManager.apiClient.get("/venues/\(appleMapsId)") {
                // Server kennt ihn – lokal nach serverId suchen oder neu anlegen
                if let existing = fetchLocalVenueIfExists(serverVenue: serverVenue, context: context) {
                    return existing
                }

                // Server kennt ihn aber lokal noch nicht → mit serverId anlegen
                let venue = Venue(context: context)
                venue.id = UUID()
                venue.name = serverVenue.name
                venue.city = serverVenue.city
                venue.formattedAddress = serverVenue.formattedAddress
                venue.latitude = serverVenue.latitude ?? 0
                venue.longitude = serverVenue.longitude ?? 0
                venue.appleMapsId = serverVenue.appleMapsId
                venue.serverId = serverVenue.id
                venue.syncStatus = SyncStatus.pending.rawValue
                return venue
            }
        }

        if let appleMapsId = dto.appleMapsId, !appleMapsId.isEmpty {
            request.predicate = NSPredicate(format: "appleMapsId == %@", appleMapsId)
            request.fetchLimit = 1
            if let existing = try? context.fetch(request).first {
                if existing.serverId == nil {
                    existing.serverId = dto.id
                }
                return existing
            }
        }

        let venue = Venue(context: context)
        venue.id = UUID()
        venue.name = dto.name
        venue.city = dto.city
        venue.formattedAddress = dto.formattedAddress
        venue.latitude = dto.latitude ?? 0
        venue.longitude = dto.longitude ?? 0
        venue.appleMapsId = dto.appleMapsId
        venue.serverId = dto.id
        venue.syncStatus = SyncStatus.pending.rawValue
        return venue
    }

    private func fetchLocalVenueIfExists(
        serverVenue: VenueDTO,
        context: NSManagedObjectContext
    ) -> Venue? {

        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.fetchLimit = 1

        request.predicate = NSPredicate(format: "serverId == %@", serverVenue.id)
        if let existing = try? context.fetch(request).first {
            return existing
        }

        if let appleId = serverVenue.appleMapsId, !appleId.isEmpty {
            request.predicate = NSPredicate(format: "appleMapsId == %@", appleId)
            if let existing = try? context.fetch(request).first {
                existing.serverId = serverVenue.id
                existing.syncStatus = SyncStatus.synced.rawValue
                return existing
            }
        }

        return nil
    }

    func getCurrentUserId() async -> String {
        do {
            return try await userSessionManager.loadUser().id.uuidString.lowercased()
        } catch {
            return "unknown"
        }
    }

    // MARK: - Setlist

    private func buildSetlist(from items: [TempCeateSetlistItem], concertId: String, context: NSManagedObjectContext) -> [SetlistItem] {
        var createdItems = [SetlistItem]()

        for item in items {
            let setlistItem = buildSetlistItem(from: item, concertId: concertId, context: context)
            createdItems.append(setlistItem)
        }

        return createdItems
    }

    private func buildSetlistItem(from item: TempCeateSetlistItem, concertId: String, context: NSManagedObjectContext) -> SetlistItem {
        let setlistItem = SetlistItem(context: context)
        setlistItem.id = UUID()
        setlistItem.concertId = concertId
        setlistItem.title = item.title
        setlistItem.spotifyTrackId = item.spotifyTrackId
        setlistItem.albumName = item.albumName
        setlistItem.artistNames = item.artistNames
        setlistItem.position = Int16(item.position)
        setlistItem.section = item.section
        setlistItem.serverId = nil
        setlistItem.coverImage = item.coverImage
        setlistItem.locallyModifiedAt = Date()
        setlistItem.syncStatus = SyncStatus.pending.rawValue

        return setlistItem
    }

    // MARK: - Travel Builder

    private func buildTravel(from dto: TravelDTO, context: NSManagedObjectContext) -> Travel {
        let travel = Travel(context: context)
        travel.travelType     = dto.travelType?.rawValue
        travel.travelDuration = dto.travelDuration ?? 0
        travel.travelDistance = dto.travelDistance ?? 0
        travel.arrivedAt      = dto.arrivedAt

        if let travelExpenses = dto.travelExpenses {
            travel.travelExpensesValue = NSDecimalNumber(decimal: travelExpenses.value)
            travel.travelExpensesCurrency = travelExpenses.currency
        }

        if let hotelExpenses = dto.hotelExpenses {
            travel.hotelExpensesValue = NSDecimalNumber(decimal: hotelExpenses.value)
            travel.hotelExpensesCurrency = hotelExpenses.currency
        }
        
        return travel
    }

    // MARK: - Ticket Builder

    private func buildTicket(from dto: TicketDTO, context: NSManagedObjectContext) -> Ticket {
        let ticket = Ticket(context: context)
        ticket.ticketType       = dto.ticketType.rawValue
        ticket.ticketCategory   = dto.ticketCategory.rawValue
        ticket.seatBlock        = dto.seatBlock
        ticket.seatRow          = dto.seatRow
        ticket.seatNumber       = dto.seatNumber
        ticket.standingPosition = dto.standingPosition
        ticket.notes            = dto.notes
        if let ticketPrice = dto.ticketPrice {
            ticket.ticketPriceValue = NSDecimalNumber(decimal: ticketPrice.value)
            ticket.ticketPriceCurrency = ticketPrice.currency
        }

        return ticket
    }
}

enum RepositoryError: Error {
    case noPermission
    case syncFailed
    case conflictDetected
}
