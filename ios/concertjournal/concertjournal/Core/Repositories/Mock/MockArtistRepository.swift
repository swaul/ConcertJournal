//
//  MockArtistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Foundation

class MockArtistRepository: ArtistRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var mockArtists: [Artist] = []
    var createdArtistId: String = UUID().uuidString

    func getOrCreateArtist(_ artist: Artist) async throws -> String {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        // Check if exists
        if let existing = mockArtists.first(where: {
            $0.spotifyArtistId == artist.spotifyArtistId || $0.name == artist.name
        }) {
            return existing.id
        }

        // Create new
        let newArtist = Artist(
            name: artist.name,
            imageUrl: artist.imageUrl,
            spotifyArtistId: artist.spotifyArtistId
        )
        mockArtists.append(newArtist)

        return createdArtistId
    }

    func searchArtists(query: String) async throws -> [Artist] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockArtists.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func fetchArtist(id: String) async throws -> Artist {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        guard let artist = mockArtists.first(where: { $0.id == id }) else {
            throw NetworkError.notFound
        }

        return artist
    }
}
