//
//  ArtistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol ArtistRepositoryProtocol {
    func searchArtists(query: String) async throws -> [Artist]
    func getOrCreateArtist(_ artist: CreateArtistDTO) async throws -> Artist
}

class BFFArtistRepository: ArtistRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func searchArtists(query: String) async throws -> [Artist] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/artists/search?q=\(encoded)")
    }
    
    func getOrCreateArtist(_ artist: CreateArtistDTO) async throws -> Artist {
        let response: Artist = try await client.post("/artists", body: artist)
        return response
    }
}
