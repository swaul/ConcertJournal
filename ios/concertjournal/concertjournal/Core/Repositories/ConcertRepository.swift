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
    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> { get }
    var cachedConcerts: [FullConcertVisit] { get }
    
    func fetchConcerts(reload: Bool) async throws -> [FullConcertVisit]
    func getConcert(id: String) async throws -> FullConcertVisit
    func reloadConcerts() async throws
    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws
    func deleteConcert(id: String) async throws

    func reset()
}

class BFFConcertRepository: ConcertRepositoryProtocol {
    
    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> {
        concertsSubject.eraseToAnyPublisher()
    }

    let concertsSubject = PassthroughSubject<[FullConcertVisit], Never>()
    
    var cachedConcerts = [FullConcertVisit]()
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func reloadConcerts() async throws {
        logInfo("Reloading concerts", category: .repository)
        _ = try await fetchConcerts(reload: true)
    }
    
    func fetchConcerts(reload: Bool = false) async throws -> [FullConcertVisit] {
        guard cachedConcerts.isEmpty || reload else {
            logSuccess("Returning \(cachedConcerts.count) cached concerts", category: .repository)
            return cachedConcerts
        }
        logInfo("Loading concerts", category: .repository)

        let concerts: [FullConcertVisit] = try await client.get("/concerts")
        logSuccess("Loaded \(concerts.count) concerts", category: .repository)
        self.cachedConcerts = concerts
        concertsSubject.send(concerts)
        return concerts
    }
    
    func getConcert(id: String) async throws -> FullConcertVisit {
        logInfo("Getting details for concert with id: \(id)", category: .repository)
        return try await client.get("/concerts/\(id)")
    }
    
    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit {
        logInfo("Creating concert with title: \(concert.title)", category: .repository)
        return try await client.post("/concerts", body: concert)
    }
    
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
        logInfo("Updating concert with id: \(id)", category: .repository)
        return try await client.put("/concerts/\(id)", body: concert)
    }

    func deleteConcert(id: String) async throws {
        logInfo("Deleting concert with id: \(id)", category: .repository)
        try await client.delete("/concerts/\(id)")
    }

    func reset() {
        cachedConcerts.removeAll()
    }
}

// MARK: - Mock Repository für Testing/Previews

//class MockConcertRepository: ConcertRepositoryProtocol {
//
//    var mockConcerts: [FullConcertVisit] = []
//
//    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> {
//        Just(concerts).eraseToAnyPublisher()
//    }
//
//    var concerts: [FullConcertVisit]
//
//    init(mockConcerts: [FullConcertVisit], concerts: [FullConcertVisit]) {
//        self.mockConcerts = mockConcerts
//        self.concerts = concerts
//    }
//
//    func getConcerts(reload: Bool) async throws -> [FullConcertVisit] {
//        if reload {
//            try await fetchConcerts()
//            return concerts
//        } else {
//            return concerts
//        }
//    }
//
//    func fetchConcerts() async throws {
//        // Mock implementation
//    }
//
//    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit {
//        // Mock implementation
//        return
//    }
//
//    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
//        // Mock implementation
//    }
//
//    func deleteConcert(id: String) async throws {
//        // Mock implementation
//    }
//}

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
    var notes: String?
    var venueId: String?
    var city: String?
    var rating: Int?

    var travelType: TravelType?
    var travelDuration: TimeInterval?
    var travelDistance: Double?
    var travelExpenses: Price?
    var hotelExpenses: Price?

    var ticketType: TicketType?
    var ticketCategory: TicketCategory?
    var ticketPrice: Price?
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
        if let notes = notes { dict["notes"] = notes }
        if let venueId = venueId { dict["venueId"] = venueId }
        if let city = city { dict["city"] = city }
        if let rating = rating { dict["rating"] = rating }

        if let travelType = travelType { dict["travelType"] = travelType }
        if let travelDuration = travelDuration { dict["travelDuration"] = travelDuration }
        if let travelDistance = travelDistance { dict["travelDistance"] = travelDistance }
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
        case notes
        case venueId = "venue_id"
        case city
        case rating

        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
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

extension FullConcertVisit {

    func detectChanges(from update: ConcertUpdate) -> (changes: ConcertChanges, dto: ConcertVisitUpdateDTO) {
        var changes = ConcertChanges()
        var dto = ConcertVisitUpdateDTO()

        // Basic Changes
        if self.title != update.title {
            dto.title = update.title
            changes.changedFields.append("title")
            changes.hasBasicChanges = true
        }

        if self.date.supabseDateString != update.date {
            dto.date = update.date
            changes.changedFields.append("date")
            changes.hasBasicChanges = true
        }

        if self.notes != update.notes {
            dto.notes = update.notes
            changes.changedFields.append("notes")
            changes.hasBasicChanges = true
        }

        if self.venue?.id != update.venue?.id {
            dto.venueId = update.venue?.id
            changes.changedFields.append("venueId")
            changes.hasBasicChanges = true
        }

        if self.city != update.city {
            dto.city = update.city
            changes.changedFields.append("city")
            changes.hasBasicChanges = true
        }

        if self.rating != update.rating {
            dto.rating = update.rating
            changes.changedFields.append("rating")
            changes.hasBasicChanges = true
        }

        // Travel Changes
        if let updateTravel = update.travel {
            var travelChanged = false

            if self.travel?.travelType != updateTravel.travelType {
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

            if self.ticket?.ticketType != updateTicket.ticketType {
                dto.ticketType = updateTicket.ticketType
                changes.changedFields.append("ticketType")
                ticketChanged = true
            }

            if self.ticket?.ticketCategory != updateTicket.ticketCategory {
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
            let currentSetlistIds = Set(self.setlistItems?.map { $0.id } ?? [])
            let updateSetlistIds = Set(updateSetlistItems.compactMap { $0.id })

            if currentSetlistIds != updateSetlistIds {
                changes.hasSetlistChanges = true
                changes.changedFields.append("setlistItems")
            }
        }

        return (changes, dto)
    }

    // Helper: Vergleiche Prices
    private func arePricesEqual(_ price1: Price?, _ price2: Price?) -> Bool {
        switch (price1, price2) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (p1?, p2?): return p1.value == p2.value && p1.currency == p2.currency
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
