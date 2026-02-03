//
//  MockConcertRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation
import Combine

class MockConcertRepository: ConcertRepositoryProtocol {

    // Configurable behavior
    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    // Mock data
    var mockConcerts: [FullConcertVisit] = []

    // Publishers
    private let concertsSubject = PassthroughSubject<[FullConcertVisit], Never>()

    var concertsDidUpdate: AnyPublisher<[FullConcertVisit], Never> {
        concertsSubject.eraseToAnyPublisher()
    }

    var concerts: [FullConcertVisit] {
        mockConcerts
    }

    // MARK: - Functions

    func getConcerts(reload: Bool) async throws -> [FullConcertVisit] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockConcerts
    }

    func fetchConcerts() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        concertsSubject.send(mockConcerts)
    }

    func createConcert(_ concert: NewConcertDTO) async throws -> ConcertVisit {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        let newConcert = ConcertVisit(
            id: UUID().uuidString,
            createdAt: Date().supabseDateString,
            updatedAt: Date().supabseDateString,
            userId: concert.userId,
            artistId: concert.artistId,
            date: concert.date,
            venueId: concert.venueId,
            city: concert.city,
            notes: concert.notes,
            rating: concert.rating,
            title: concert.title
        )

        return newConcert
    }

    func updateConcert(id: String, concert: ConcertVisitUpdateDTO) async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        // Update mock data
        if let index = mockConcerts.firstIndex(where: { $0.id == id }) {
            // Update the concert in mockConcerts
            // (Implementation depends on how you want to handle this)
        }
    }

    func deleteConcert(id: String) async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        mockConcerts.removeAll { $0.id == id }
        concertsSubject.send(mockConcerts)
    }
}
