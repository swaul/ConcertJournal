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
    
    func fetchConcerts(for userId: String, reload: Bool) async throws -> [FullConcertVisit]
    func getConcert(id: String) async throws -> FullConcertVisit
    func reloadConcerts() async throws
    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws
    func deleteConcert(id: String) async throws
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
        let concerts: [FullConcertVisit] = try await client.get("/concerts")
        concertsSubject.send(concerts)
        self.cachedConcerts = concerts
    }
    
    func fetchConcerts(for userId: String, reload: Bool = false) async throws -> [FullConcertVisit] {
        guard cachedConcerts.isEmpty || reload else { return cachedConcerts }
        let concerts: [FullConcertVisit] = try await client.get("/concerts")
        self.cachedConcerts = concerts
        concertsSubject.send(concerts)
        return concerts
    }
    
    func getConcert(id: String) async throws -> FullConcertVisit {
        try await client.get("/concerts/\(id)")
    }
    
    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit {
        try await client.post("/concerts", body: concert)
    }
    
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
        let _: FullConcertVisit = try await client.patch("/concerts/\(id)", body: concert)
    }
    
    func deleteConcert(id: String) async throws {
        try await client.delete("/concerts/\(id)")
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

struct ConcertVisitUpdateDTO: Encodable {
    let title: String
    let date: String
    let notes: String
    let venueId: String?
    let city: String?
    let rating: Int
    let setlistItems: [CreateSetlistItemDTO]?
    
    enum CodingKeys: String, CodingKey {
        case title
        case date
        case notes
        case venueId = "venue_id"
        case city
        case rating
        case setlistItems = "setlist_items"
    }

    init(update: ConcertUpdate) {
        self.title = update.title
        self.date = update.date
        self.notes = update.notes
        self.venueId = update.venue?.id
        self.city = update.city
        self.rating = update.rating
        if let setlistItems = update.setlistItems {
            self.setlistItems = setlistItems.map { CreateSetlistItemDTO(concertId: update.id, item: $0) }
        } else {
            self.setlistItems = nil
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
