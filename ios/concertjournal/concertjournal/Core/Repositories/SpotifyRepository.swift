//
//  SpotifyRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol SpotifyRepositoryProtocol {
    func searchSongs(query: String) async throws -> [SpotifySong]
    func searchArtist(query: String) async throws -> [SpotifyArtist]
}

class BFFSpotifyRepository: SpotifyRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }

    func searchSongs(query: String) async throws -> [SpotifySong] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/spotify/search/tracks?q=\(encoded)")
    }

    func searchArtist(query: String) async throws -> [SpotifyArtist] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/spotify/search/artists?q=\(encoded)")
    }
}
