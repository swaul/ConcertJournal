//
//  OfflineConcertRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import CoreData
import Combine

protocol OfflineConcertRepositoryProtocol {
    func fetchConcerts() -> [Concert]
    func fetchConcertsWithArtist(_ id: UUID) -> [Concert]
    func getConcert(id: UUID) -> Concert?
    func createConcert(_ dto: CreateConcertDTO) throws -> Concert
    func updateConcert(_ concert: Concert, with dto: ConcertUpdate) throws
    func deleteConcert(_ concert: Concert) throws
    func presaveArtist(_ newArtist: ArtistDTO) throws -> Artist
    func sync() async throws
}

class OfflineConcertRepository: OfflineConcertRepositoryProtocol {

    private let coreData = CoreDataStack.shared
    private let syncManager: SyncManager

    init(syncManager: SyncManager) {
        self.syncManager = syncManager
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

    func createConcert(_ dto: CreateConcertDTO) throws -> Concert {
        let context = coreData.viewContext

        // 1. Create in Core Data
        let concert = Concert(context: context)
        concert.id = UUID()
        concert.title = dto.title
        concert.date = dto.date
        concert.notes = dto.notes
        concert.rating = Int16(dto.rating ?? 0)
        concert.city = dto.city

        // Set sync metadata
        concert.syncStatus = SyncStatus.pending.rawValue
        concert.locallyModifiedAt = Date()
        concert.syncVersion = 1
        concert.ownerId = getCurrentUserId()
        concert.isOwner = true
        concert.canEdit = true

        // Artist & Venue
        concert.artist = fetchOrCreateArtist(from: dto.artist, context: context)

        if let venue = dto.venue {
            concert.venue = fetchOrCreateVenue(from: venue, context: context)
        }

        // Support Acts
        for actDTO in dto.supportActs {
            let act = fetchOrCreateArtist(from: actDTO, context: context)
            concert.addSupportAct(act)
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

        // 3. Queue for sync
        Task {
            await syncManager.syncConcert(concert)
        }

        return concert
    }

    // MARK: - Update (Local First)

    func updateConcert(_ concert: Concert, with dto: ConcertUpdate) throws {
        let context = coreData.viewContext

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
            concert.venue = fetchOrCreateVenue(from: venueDTO, context: context)
        }
        
        if let buddies = dto.buddyAttendees {
            concert.setBuddies(buddies)
        }

        // Support Acts: alte entfernen, neue setzen
        if let newActs = dto.supportActs {
            (concert.supportActs as? Set<Artist>)?.forEach { concert.removeSupportAct($0) }
            for actDTO in newActs {
                concert.addSupportAct(fetchOrCreateArtist(from: actDTO, context: context))
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

    func deleteConcert(_ concert: Concert) throws {
        let context = coreData.viewContext

        // Check permission
        guard concert.canEdit else {
            throw RepositoryError.noPermission
        }

        // 1. Mark as deleted (soft delete)
        concert.syncStatus = SyncStatus.deleted.rawValue
        concert.locallyModifiedAt = Date()

        // 2. Save
        try coreData.saveWithResult()

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
    ) -> Artist {
        // Schon in Core Data?
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(
            format: "spotifyArtistId == %@", dto.spotifyArtistId ?? ""
        )
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing  // ✅ Bereits bekannter Artist
        }

        // Neu anlegen
        let artist = Artist(context: context)
        artist.id = UUID()
        artist.name = dto.name
        artist.imageUrl = dto.imageUrl
        artist.spotifyArtistId = dto.spotifyArtistId
        artist.syncStatus = SyncStatus.pending.rawValue
        return artist
    }

    private func fetchOrCreateVenue(
        from dto: VenueDTO,
        context: NSManagedObjectContext
    ) -> Venue {
        if let appleMapsId = dto.appleMapsId {
            let request: NSFetchRequest<Venue> = Venue.fetchRequest()
            request.predicate = NSPredicate(format: "appleMapsId == %@", appleMapsId)
            request.fetchLimit = 1

            if let existing = try? context.fetch(request).first {
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
        venue.syncStatus = SyncStatus.pending.rawValue
        return venue
    }

    private func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? "unknown"
    }

    // MARK: - Travel Builder

    private func buildTravel(from dto: TravelDTO, context: NSManagedObjectContext) -> Travel {
        let travel = Travel(context: context)
        travel.travelType     = dto.travelType?.rawValue
        travel.travelDuration = dto.travelDuration ?? 0
        travel.travelDistance = dto.travelDistance ?? 0
        travel.arrivedAt      = dto.arrivedAt

        if let expensesDTO = dto.travelExpenses {
            travel.travelExpenses = buildPrice(from: expensesDTO, context: context)
        }
        if let hotelDTO = dto.hotelExpenses {
            travel.hotelExpenses = buildPrice(from: hotelDTO, context: context)
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

        if let priceDTO = dto.ticketPrice {
            ticket.ticketPrice = buildPrice(from: priceDTO, context: context)
        }

        return ticket
    }

    // MARK: - Price Builder

    private func buildPrice(from dto: PriceDTO, context: NSManagedObjectContext) -> Price {
        let price = Price(context: context)
        price.value    = NSDecimalNumber(decimal: dto.value).doubleValue
        price.currency = dto.currency
        return price
    }
}

enum RepositoryError: Error {
    case noPermission
    case syncFailed
    case conflictDetected
}
