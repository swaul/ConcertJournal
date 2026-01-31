//
//  MockSpotifyRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

class MockSpotifyRepository: SpotifyRepositoryProtocol {

    var mockToken: String = "mock-token-12345"
    var mockSongs: [SpotifySong] = []
    var mockArtists: [SpotifyArtist] = []

    func fetchAccessToken() async throws -> String {
        return mockToken
    }

    func searchSongs(query: String) async throws -> [SpotifySong] {
        return mockSongs
    }

    func searchArtist(query: String) async throws -> [SpotifyArtist] {
        return mockArtists
    }
}
