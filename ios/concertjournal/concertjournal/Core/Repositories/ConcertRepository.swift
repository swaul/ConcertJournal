//
//  ConcertRepository.swift
//  concertjournal
//
//  Repository für Concert-Daten - abstrahiert die Datenquelle
//

import Combine
import Foundation
import Supabase

protocol ConcertRepositoryProtocol {
    func fetchConcerts() async throws -> [PartialConcertVisit]
    func fetchConcertsWithArtist(artistId: String) async throws -> [ConcertDetails]
    func getConcert(id: UUID) async throws -> FullConcertVisit
    func createConcert(_ concert: NewConcertDTO) async throws -> CreateConcertResponse
    func updateConcert(id: UUID, concert: ConcertVisitUpdateDTO) async throws
    func deleteConcert(id: UUID) async throws
}

class BFFConcertRepository: ConcertRepositoryProtocol {
    
    var concertsDidUpdate: AnyPublisher<[PartialConcertVisit], Never> {
        concertsSubject.eraseToAnyPublisher()
    }

    let concertsSubject = PassthroughSubject<[PartialConcertVisit], Never>()

    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func fetchConcerts() async throws -> [PartialConcertVisit] {
        let concerts: [PartialConcertVisit] = try await client.get("/concerts")
        logSuccess("Loaded \(concerts.count) concerts", category: .repository)
        concertsSubject.send(concerts)
        return concerts
    }

    func fetchConcertsWithArtist(artistId: String) async throws -> [ConcertDetails] {
        logInfo("Getting concert details with artistid: \(artistId)", category: .repository)
        return try await client.get("/concerts/withArtist/\(artistId)")
    }

    func getConcert(id: UUID) async throws -> FullConcertVisit {
        logInfo("Getting details for concert with id: \(id)", category: .repository)
        return try await client.get("/concerts/\(id)")
    }
    
    func createConcert(_ concert: NewConcertDTO) async throws -> CreateConcertResponse {
        logInfo("Creating concert with title: \(concert.title)", category: .repository)
        return try await client.post("/concerts", body: concert)
    }
    
    func updateConcert(id: UUID, concert: ConcertVisitUpdateDTO) async throws {
        logInfo("Updating concert with id: \(id)", category: .repository)
        return try await client.put("/concerts/\(id)", body: concert)
    }

    func deleteConcert(id: UUID) async throws {
        logInfo("Deleting concert with id: \(id)", category: .repository)
        try await client.delete("/concerts/\(id)")
    }
}

struct CreateConcertResponse: Codable {
    let id: String
}

struct ConcertChanges {
    var hasBasicChanges: Bool = false
    var hasTravelChanges: Bool = false
    var hasTicketChanges: Bool = false
    var hasSetlistChanges: Bool = false

    var changedFields: [String] = []

    var hasAnyChanges: Bool {
        hasBasicChanges || hasTravelChanges || hasTicketChanges || hasSetlistChanges
    }
}

struct ConcertVisitUpdateDTO: Codable {
    var title: String?
    var date: String?
    var openingTime: String?
    var notes: String?
    var venueId: String?
    var city: String?
    var rating: Int?
    var supportActs: [ArtistDTO]?

    var travelType: TravelType?
    var travelDuration: TimeInterval?
    var travelDistance: Double?
    var arrivedAt: String?
    var travelExpenses: PriceDTO?
    var hotelExpenses: PriceDTO?

    var ticketType: TicketType?
    var ticketCategory: TicketCategory?
    var ticketPrice: PriceDTO?
    var seatBlock: String?
    var seatRow: String?
    var seatNumber: String?
    var standingPosition: String?
    var ticketNotes: String?

    // Helper: Konvertiere zu Dictionary für Logging
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let title = title { dict["title"] = title }
        if let date = date { dict["date"] = date }
        if let openingTime = openingTime { dict["openingTime"] = openingTime }
        if let notes = notes { dict["notes"] = notes }
        if let venueId = venueId { dict["venueId"] = venueId }
        if let city = city { dict["city"] = city }
        if let rating = rating { dict["rating"] = rating }
        if let supportActs = supportActs { dict["supportActs"] = supportActs.map { $0.id } }

        if let travelType = travelType { dict["travelType"] = travelType }
        if let travelDuration = travelDuration { dict["travelDuration"] = travelDuration }
        if let travelDistance = travelDistance { dict["travelDistance"] = travelDistance }
        if let arrivedAt = arrivedAt { dict["arrivedAt"] = arrivedAt }
        if let travelExpenses = travelExpenses { dict["travelExpenses"] = travelExpenses }
        if let hotelExpenses = hotelExpenses { dict["hotelExpenses"] = hotelExpenses }

        if let ticketType = ticketType { dict["ticketType"] = ticketType }
        if let ticketCategory = ticketCategory { dict["ticketCategory"] = ticketCategory }
        if let ticketPrice = ticketPrice { dict["ticketPrice"] = ticketPrice }

        if let seatBlock = seatBlock { dict["seatBlock"] = seatBlock}
        if let seatRow = seatRow { dict["seatRow"] = seatRow}
        if let seatNumber = seatNumber { dict["seatNumber"] = seatNumber}
        if let standingPosition = standingPosition { dict["standingPosition"] = standingPosition}
        if let ticketNotes = ticketNotes { dict["ticketNotes"] = ticketNotes}

        return dict
    }

    var isEmpty: Bool {
        toDictionary().isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case openingTime = "opening_time"
        case notes
        case venueId = "venue_id"
        case city
        case rating
        case supportActs = "support_acts_ids"

        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case arrivedAt = "arrived_at"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"

        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case ticketPrice = "ticket_price"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
    }
}

extension Concert {

    func detectChanges(from update: ConcertUpdate) -> (changes: ConcertChanges, dto: ConcertVisitUpdateDTO) {
        var changes = ConcertChanges()
        var dto = ConcertVisitUpdateDTO()

        // Basic Changes
        if self.title != update.title {
            dto.title = update.title
            changes.changedFields.append("title")
            changes.hasBasicChanges = true
        }

        if self.date != update.date {
            dto.date = update.date.supabseDateString
            changes.changedFields.append("date")
            changes.hasBasicChanges = true
        }

        if self.openingTime != update.openingTime {
            dto.openingTime = update.openingTime?.supabseDateString
            changes.changedFields.append("openingTime")
            changes.hasBasicChanges = true
        }

        if self.notes != update.notes {
            dto.notes = update.notes
            changes.changedFields.append("notes")
            changes.hasBasicChanges = true
        }

        if self.venue?.id.uuidString != update.venue?.id {
            dto.venueId = update.venue?.id
            changes.changedFields.append("venueId")
            changes.hasBasicChanges = true
        }

        if self.city != update.city {
            dto.city = update.city
            changes.changedFields.append("city")
            changes.hasBasicChanges = true
        }

        if self.rating != update.rating ?? -1 {
            dto.rating = update.rating
            changes.changedFields.append("rating")
            changes.hasBasicChanges = true
        }


        if let updatedSupportActs = update.supportActs,
           self.supportActsArray.map({ $0.id.uuidString }) != updatedSupportActs.map({ $0.id }) {
            dto.supportActs = update.supportActs
            changes.changedFields.append("supportActs")
            changes.hasBasicChanges = true
        }

        // Travel Changes
        if let updateTravel = update.travel {
            var travelChanged = false

            if self.travel?.travelTypeEnum != updateTravel.travelType {
                dto.travelType = updateTravel.travelType
                changes.changedFields.append("travelType")
                travelChanged = true
            }

            if self.travel?.travelDuration != updateTravel.travelDuration {
                dto.travelDuration = updateTravel.travelDuration
                changes.changedFields.append("travelDuration")
                travelChanged = true
            }

            if self.travel?.travelDistance != updateTravel.travelDistance {
                dto.travelDistance = updateTravel.travelDistance
                changes.changedFields.append("travelDistance")
                travelChanged = true
            }

            if self.travel?.arrivedAt != updateTravel.arrivedAt {
                dto.arrivedAt = updateTravel.arrivedAt?.supabseDateString
                changes.changedFields.append("arrivedAt")
                travelChanged = true
            }

            if !arePricesEqual(self.travel?.travelExpenses, updateTravel.travelExpenses) {
                dto.travelExpenses = updateTravel.travelExpenses
                changes.changedFields.append("travelExpenses")
                travelChanged = true
            }

            if !arePricesEqual(self.travel?.hotelExpenses, updateTravel.hotelExpenses) {
                dto.hotelExpenses = updateTravel.hotelExpenses
                changes.changedFields.append("hotelExpenses")
                travelChanged = true
            }

            changes.hasTravelChanges = travelChanged
        }

        // Ticket Changes
        if let updateTicket = update.ticket {
            var ticketChanged = false

            if self.ticket?.ticketTypeEnum != updateTicket.ticketType {
                dto.ticketType = updateTicket.ticketType
                changes.changedFields.append("ticketType")
                ticketChanged = true
            }

            if self.ticket?.ticketCategoryEnum != updateTicket.ticketCategory {
                dto.ticketCategory = updateTicket.ticketCategory
                changes.changedFields.append("ticketCategory")
                ticketChanged = true
            }

            if !arePricesEqual(self.ticket?.ticketPrice, updateTicket.ticketPrice) {
                dto.ticketPrice = updateTicket.ticketPrice
                changes.changedFields.append("ticketPrice")
                ticketChanged = true
            }

            if self.ticket?.seatBlock != updateTicket.seatBlock {
                dto.seatBlock = updateTicket.seatBlock
                changes.changedFields.append("seatBlock")
                ticketChanged = true
            }

            if self.ticket?.seatRow != updateTicket.seatRow {
                dto.seatRow = updateTicket.seatRow
                changes.changedFields.append("seatRow")
                ticketChanged = true
            }

            if self.ticket?.seatNumber != updateTicket.seatNumber {
                dto.seatNumber = updateTicket.seatNumber
                changes.changedFields.append("seatNumber")
                ticketChanged = true
            }

            if self.ticket?.standingPosition != updateTicket.standingPosition {
                dto.standingPosition = updateTicket.standingPosition
                changes.changedFields.append("standingPosition")
                ticketChanged = true
            }

            if self.ticket?.notes != updateTicket.notes {
                dto.ticketNotes = updateTicket.notes
                changes.changedFields.append("ticketNotes")
                ticketChanged = true
            }

            changes.hasTicketChanges = ticketChanged
        }

        // Setlist Changes
        if let updateSetlistItems = update.setlistItems {
            let currentSetlistIds = Set(self.setlistItemsArray.map { $0.id?.uuidString })
            let updateSetlistIds = Set(updateSetlistItems.compactMap { $0.id })

            if currentSetlistIds != updateSetlistIds {
                changes.hasSetlistChanges = true
                changes.changedFields.append("setlistItems")
            }
        }

        return (changes, dto)
    }

    // Helper: Vergleiche Prices
    private func arePricesEqual(_ price1: Price?, _ price2: PriceDTO?) -> Bool {
        switch (price1, price2) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (p1?, p2?): return Decimal(p1.value) == p2.value && p1.currency == p2.currency
        }
    }
}


extension Date {
    public var supabseDateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}

extension String {
    public var supabaseStringDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }
}
