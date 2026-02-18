//
//  SyncManager.swift
//  concertjournal
//

import CoreData
import Foundation
import Combine

class SyncManager {

    let coreData = CoreDataStack.shared
    var isSyncing = false
    let apiClient: BFFClient

    private let userSessionManager: UserSessionManagerProtocol
    var artistRepository: BFFArtistRepository? = nil
    var venueRepository: BFFVenueRepository? = nil

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
        defer { isSyncing = false }

        await resetOldErrorStates()

        logInfo("Starting full sync", category: .sync)

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

        let context = coreData.newBackgroundContext()
        await context.perform {
            guard let bgConcert = try? context.existingObject(with: concert.objectID) as? Concert else {
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

        try await context.perform {
            for serverConcert in response.concerts {
                try self.mergeConcertFromServerSync(serverConcert, context: context)
            }
            for deletedId in response.deleted {
                self.deleteConcertFromServerSync(deletedId, context: context)
            }
            if context.hasChanges {
                try context.save()
            }
        }

        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        }

        logSuccess("Pulled \(response.concerts.count) concerts", category: .sync)
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

        if let serverId = payload.serverId {
            // Update
            logInfo("Updating Concert \"\(serverId)\"", category: .sync)
            let _: ServerConcert = try await apiClient.put("/sync/concerts/\(serverId)", body: payload)
        } else {
            logInfo("Creating Concert \"\(payload.title ?? payload.artist.name)\"", category: .sync)
            // Create
            if payload.artistServerId == nil {
                logInfo("Concert in sync has artist \"\(payload.artist.name)\" which does not exist on the server", category: .sync)
                logInfo("Creating \"\(payload.artist.name)\"", category: .sync)
                let serverArtist: ArtistDTO = try await apiClient.post("/artists", body: CreateArtistDTO(artist: payload.artist))
                logSuccess("Successfully created \"\(payload.artist.name)\"", category: .sync)
                payload.artistServerId = serverArtist.id
            }
            if let venue = payload.venue, payload.venueServerId == nil {
                logInfo("Concert in sync has venue \"\(venue.name)\" which does not exist on the server", category: .sync)
                logInfo("Creating \"\(venue.name)\"", category: .sync)
                let serverVenue: IDResponse = try await apiClient.post("/venues", body: venue)
                logSuccess("Successfully created \"\(venue.name)\"", category: .sync)
                payload.venueServerId = serverVenue.id
            }
            if payload.supportActServerIds?.count != payload.supportActs?.count {
                logInfo("Concert in sync has support acts \"\(payload.supportActs?.map { $0.name } ?? [])\" which do not exist on the server", category: .sync)
                logInfo("Creating \"\(payload.supportActs?.map { $0.name } ?? [])\"", category: .sync)
                var supportActsIds = [String]()
                for artist in payload.supportActs ?? [] {
                    let serverArtist: ArtistDTO = try await apiClient.post("/artists", body: CreateArtistDTO(artist: artist))
                    supportActsIds.append(serverArtist.id)
                }
                logSuccess("Successfully created \"\(payload.supportActs?.map { $0.name } ?? [])\"", category: .sync)

                payload.supportActServerIds = supportActsIds
            }

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

    private func mergeConcertFromServerSync(_ serverConcert: ServerConcert, context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverConcert.id)
        request.fetchLimit = 1

        if let existing = try context.fetch(request).first {
            updateConcertSync(existing, with: serverConcert, context: context)
        } else {
            createConcertSync(serverConcert, context: context)
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

    private func updateConcertSync(_ concert: Concert, with server: ServerConcert, context: NSManagedObjectContext) {
        if concert.syncStatus == SyncStatus.pending.rawValue,
           let serverModified = server.updatedAt,
           let localModified = concert.locallyModifiedAt,
           localModified > serverModified {
            concert.syncStatus = SyncStatus.conflict.rawValue
            logWarning("Conflict for: \(concert.title ?? "?")", category: .sync)
            return
        }

        concert.title       = server.title
        concert.date        = server.date
        concert.openingTime = server.openingTime
        concert.notes       = server.notes
        concert.rating      = Int16(server.rating ?? 0)
        concert.city        = server.city

        if let artistId = server.artistId {
            concert.artist = fetchOrCreateArtistSync(serverId: artistId, context: context)
        }

        if let venueId = server.venueId {
            concert.venue = fetchOrCreateVenueSync(serverId: venueId, context: context)
        } else {
            concert.venue = nil
        }

        concert.travel = buildTravelSync(from: server, existing: concert.travel, context: context)
        concert.ticket = buildTicketSync(from: server, existing: concert.ticket, context: context)
        updateSupportActsSync(concert: concert, serverIds: server.supportActsIds ?? [], context: context)

        concert.serverModifiedAt = server.updatedAt
        concert.syncStatus       = SyncStatus.synced.rawValue
        concert.lastSyncedAt     = Date()
    }

    // MARK: - Create new Concert

    private func createConcertSync(_ server: ServerConcert, context: NSManagedObjectContext) {
        let concert = Concert(context: context)
        concert.id       = UUID()
        concert.serverId = server.id

        concert.title       = server.title
        concert.date        = server.date
        concert.openingTime = server.openingTime
        concert.notes       = server.notes
        concert.rating      = Int16(server.rating ?? 0)
        concert.city        = server.city

        if let artistId = server.artistId {
            concert.artist = fetchOrCreateArtistSync(serverId: artistId, context: context)
        }

        if let venueId = server.venueId {
            concert.venue = fetchOrCreateVenueSync(serverId: venueId, context: context)
        }

        concert.travel = buildTravelSync(from: server, existing: nil, context: context)
        concert.ticket = buildTicketSync(from: server, existing: nil, context: context)
        updateSupportActsSync(concert: concert, serverIds: server.supportActsIds ?? [], context: context)

        let currentUserId = Self.getCurrentUserIdStatic()
        concert.ownerId  = server.userId
        concert.isOwner  = server.userId == currentUserId
        concert.canEdit  = concert.isOwner

        concert.syncStatus        = SyncStatus.synced.rawValue
        concert.lastSyncedAt      = Date()
        concert.serverModifiedAt  = server.updatedAt
        concert.locallyModifiedAt = Date()
        concert.syncVersion       = 1
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

        travel.travelExpenses = buildPriceSync(
            from: server.travelExpenses,
            existing: travel.travelExpenses,
            context: context
        )
        travel.hotelExpenses = buildPriceSync(
            from: server.hotelExpenses,
            existing: travel.hotelExpenses,
            context: context
        )
        return travel
    }

    // MARK: - Ticket Builder

    private func buildTicketSync(
        from server: ServerConcert,
        existing: Ticket?,
        context: NSManagedObjectContext
    ) -> Ticket? {
        guard server.ticketType != nil
                || server.ticketCategory != nil
                || server.seatBlock != nil
        else {
            if let old = existing { context.delete(old) }
            return nil
        }

        let ticket = existing ?? Ticket(context: context)
        ticket.ticketType       = server.ticketType ?? TicketType.standing.rawValue
        ticket.ticketCategory   = server.ticketCategory ?? TicketCategory.regular.rawValue
        ticket.seatBlock        = server.seatBlock
        ticket.seatRow          = server.seatRow
        ticket.seatNumber       = server.seatNumber
        ticket.standingPosition = server.standingPosition
        ticket.notes            = server.ticketNotes

        ticket.ticketPrice = buildPriceSync(
            from: server.ticketPrice,
            existing: ticket.ticketPrice,
            context: context
        )
        return ticket
    }

    // MARK: - Price Builder

    private func buildPriceSync(
        from dto: PriceDTO?,
        existing: Price?,
        context: NSManagedObjectContext
    ) -> Price? {
        guard let dto else {
            if let old = existing { context.delete(old) }
            return nil
        }

        let price = existing ?? Price(context: context)
        price.value    = NSDecimalNumber(decimal: dto.value).doubleValue
        price.currency = dto.currency
        return price
    }

    // MARK: - Support Acts Sync

    private func updateSupportActsSync(
        concert: Concert,
        serverIds: [String],
        context: NSManagedObjectContext
    ) {
        (concert.supportActs as? Set<Artist>)?.forEach { concert.removeSupportAct($0) }

        for serverId in serverIds {
            let artist = fetchOrCreateArtistSync(serverId: serverId, context: context)
            concert.addSupportAct(artist)
        }
    }

    // MARK: - Artist Sync

    private func fetchOrCreateArtistSync(serverId: String, context: NSManagedObjectContext) -> Artist {
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let artist = Artist(context: context)
        artist.id = UUID()
        artist.serverId = serverId
        artist.syncStatus = SyncStatus.pending.rawValue
        return artist
    }

    // MARK: - Venue Sync

    private func fetchOrCreateVenueSync(serverId: String, context: NSManagedObjectContext) -> Venue {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let venue = Venue(context: context)
        venue.id = UUID()
        venue.serverId = serverId
        venue.syncStatus = SyncStatus.pending.rawValue
        return venue
    }

    // MARK: - Helpers

    static func getCurrentUserIdStatic() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? "unknown"
    }
}

// MARK: - Push Payload

struct ConcertPushPayload: Encodable {
    let serverId: String?
    let title: String?
    let date: Date
    let openingTime: Date?
    let notes: String?
    let rating: Int?
    let city: String?
    let version: Int

    let artist: ArtistDTO
    var artistServerId: String?
    var venueServerId: String?
    let venue: VenueDTO?
    var supportActServerIds: [String]?
    let supportActs: [ArtistDTO]?

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
    let ticketNotes: String?

    private enum CodingKeys: String, CodingKey {
        case date, city, notes, rating, title, version
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

        artistServerId  = concert.artist.serverId
        artist = concert.artist.toDTO()
        venueServerId   = concert.venue?.serverId
        venue = concert.venue?.toDTO()

        supportActs = concert.supportActsArray.compactMap { $0.toDTO() }
        supportActServerIds = concert.supportActsArray
            .compactMap { $0.serverId }

        travelType     = concert.travel?.travelType
        travelDuration = concert.travel?.travelDuration
        travelDistance = concert.travel?.travelDistance
        arrivedAt      = concert.travel?.arrivedAt
        travelExpenses = concert.travel?.travelExpenses.map {
            PriceDTO(value: Decimal($0.value), currency: $0.currency)
        }
        hotelExpenses = concert.travel?.hotelExpenses.map {
            PriceDTO(value: Decimal($0.value), currency: $0.currency)
        }

        ticketType     = concert.ticket?.ticketType
        ticketCategory = concert.ticket?.ticketCategory
        seatBlock      = concert.ticket?.seatBlock
        seatRow        = concert.ticket?.seatRow
        seatNumber     = concert.ticket?.seatNumber
        standingPosition = concert.ticket?.standingPosition
        ticketNotes    = concert.ticket?.notes
        ticketPrice    = concert.ticket?.ticketPrice.map {
            PriceDTO(value: Decimal($0.value), currency: $0.currency)
        }
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
    let supportActsIds: [String]?
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, date, city, notes, rating, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case artistId = "artist_id"
        case venueId = "venue_id"
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
