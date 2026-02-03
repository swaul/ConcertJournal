//
//  MockSpotifyRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation

class MockSpotifyRepository: SpotifyRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var mockToken: String = "mock-token-12345"
    var mockSongs: [SpotifySong] = []
    var mockArtists: [SpotifyArtist] = []

    func fetchAccessToken() async throws -> String {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockToken
    }

    func searchSongs(query: String) async throws -> [SpotifySong] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockSongs.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func searchArtist(query: String) async throws -> [SpotifyArtist] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockArtists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func getArtistTopTracks(artistId: String) async throws -> [SpotifySong] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockSongs
    }
}
