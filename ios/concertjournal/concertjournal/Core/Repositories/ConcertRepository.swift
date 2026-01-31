//
//  ConcertRepository.swift
//  concertjournal
//
//  Repository für Concert-Daten - abstrahiert die Datenquelle
//

import Foundation
import Supabase

protocol ConcertRepositoryProtocol {
    func fetchConcerts(for userId: String) async throws -> [FullConcertVisit]
    func createConcert(_ concert: NewConcertDTO) async throws -> String
    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws
    func deleteConcert(id: String) async throws
}

class ConcertRepository: ConcertRepositoryProtocol {

    private let networkService: NetworkServiceProtocol
    private let supabaseClient: SupabaseClientManager

    init(networkService: NetworkServiceProtocol, supabaseClient: SupabaseClientManager) {
        self.networkService = networkService
        self.supabaseClient = supabaseClient
    }

    // MARK: - Fetch Concerts

    func fetchConcerts(for userId: String) async throws -> [FullConcertVisit] {
        // Dieser Query ist komplex wegen den Joins - hier nutzen wir den Supabase Client direkt
        let visits: [FullConcertVisit] = try await supabaseClient.client
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
                setlist_id,
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

        return visits
    }

    // MARK: - Create Concert

    func createConcert(_ concert: NewConcertDTO) async throws -> String {
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

// MARK: - Mock Repository für Testing/Previews

class MockConcertRepository: ConcertRepositoryProtocol {

    var mockConcerts: [FullConcertVisit] = []

    func fetchConcerts(for userId: String) async throws -> [FullConcertVisit] {
        return mockConcerts
    }

    func createConcert(_ concert: NewConcertDTO) async throws -> String {
        // Mock implementation
        return "Test"
    }

    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
        // Mock implementation
    }

    func deleteConcert(id: String) async throws {
        // Mock implementation
    }
}

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
