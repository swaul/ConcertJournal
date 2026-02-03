//
//  MockVenueRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

class MockVenueRepository: VenueRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var mockVenues: [Venue] = []
    var createdVenueId: String = UUID().uuidString

    func createVenue(_ venue: Venue) async throws -> String {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        // Check if exists
        if let existing = mockVenues.first(where: {
            $0.appleMapsId == venue.appleMapsId || $0.name == venue.name
        }) {
            return existing.id
        }

        // Create new
        let newVenue = Venue(
            id: createdVenueId,
            name: venue.name,
            formattedAddress: venue.formattedAddress,
            latitude: venue.latitude,
            longitude: venue.longitude,
            appleMapsId: venue.appleMapsId
        )
        mockVenues.append(newVenue)

        return createdVenueId
    }
}
