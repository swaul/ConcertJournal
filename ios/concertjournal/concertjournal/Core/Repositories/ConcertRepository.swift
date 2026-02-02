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

    var concerts: [FullConcertVisit] { get }
    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> { get }

    func getConcerts(reload: Bool) async throws -> [FullConcertVisit]
    func fetchConcerts() async throws
    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws
    func deleteConcert(id: String) async throws
}

class ConcertRepository: ConcertRepositoryProtocol {

    private let networkService: NetworkServiceProtocol
    private let supabaseClient: SupabaseClientManager
    private let userSessionManager: UserSessionManager

    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> {
        concertsSubject.eraseToAnyPublisher()
    }

    let concertsSubject = PassthroughSubject<[FullConcertVisit], Never>()

    var concerts: [FullConcertVisit]

    init(networkService: NetworkServiceProtocol, userSessionManager: UserSessionManager, supabaseClient: SupabaseClientManager) {
        self.networkService = networkService
        self.userSessionManager = userSessionManager
        self.supabaseClient = supabaseClient

        concerts = []
    }

    // MARK: - Fetch Concerts

    func getConcerts(reload: Bool) async throws -> [FullConcertVisit] {
        guard reload || concerts.isEmpty else {
            return concerts
        }

        try await fetchConcerts()
        return concerts
    }

    func fetchConcerts() async throws {
        guard let userId = userSessionManager.user?.id else { throw ConcertLoadingError.notLoggedIn }
        // Dieser Query ist komplex wegen den Joins - hier nutzen wir den Supabase Client direkt
        let concerts: [FullConcertVisit] = try await supabaseClient.client
            .from("concert_visits")
            .select("""
                id,
                created_at,
                updated_at,
                date,
                venues (
                    id,
                    name,
                    formatted_address,
                    latitude,
                    longitude,
                    apple_maps_id
                ),
                city,
                notes,
                rating,
                title,
                artists (
                    id,
                    name,
                    image_url,
                    spotify_artist_id
                )
            """)
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value

        self.concerts = concerts
        concertsSubject.send(concerts)
    }

    // MARK: - Create Concert

    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit {
        try await networkService.insert(into: "concert_visits", values: concert.encoded())
    }

    // MARK: - Update Concert

    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
        try await networkService.update(table: "concert_visits", id: id, values: concert.encoded())
    }

    // MARK: - Delete Concert

    func deleteConcert(id: String) async throws {
        try await networkService.delete(from: "concert_visits", id: id)
    }
}

enum ConcertLoadingError: Error, LocalizedError {
    case notLoggedIn
    case concertIdMissing

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Nicht eingeloggt"
        case .concertIdMissing:
            return "Concert id is missing"
        }
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

struct ConcertVisitUpdateDTO: SupabaseEncodable {
    let title: String
    let date: Date
    let notes: String
    let venueId: String?
    let city: String?
    let rating: Int

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case notes
        case venueId = "venue_id"
        case city
        case rating
    }

    init(update: ConcertUpdate) {
        self.title = update.title
        self.date = update.date
        self.notes = update.notes
        self.venueId = update.venue?.id
        self.city = update.city
        self.rating = update.rating
    }

    func encoded() throws -> [String : AnyJSON] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: date)

        let data: [String: AnyJSON] = [
            CodingKeys.title.rawValue: .string(title),
            CodingKeys.date.rawValue: .string(dateString),
            CodingKeys.rating.rawValue: .integer(rating),
            CodingKeys.venueId.rawValue: venueId == nil ? .null : .string(venueId!),
            CodingKeys.city.rawValue: city == nil ? .null : .string(city!),
            CodingKeys.notes.rawValue: notes.isEmpty ? .null : .string(notes)
        ]

        return data
    }
}
