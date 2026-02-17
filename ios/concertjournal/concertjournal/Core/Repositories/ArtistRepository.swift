//
//  ArtistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol ArtistRepositoryProtocol {
    func searchArtists(query: String) async throws -> [ArtistDTO]
    func getOrCreateArtist(_ artist: CreateArtistDTO) async throws -> ArtistDTO
    func getArtist(with id: String) async throws -> ArtistDTO
}

class BFFArtistRepository: ArtistRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func searchArtists(query: String) async throws -> [ArtistDTO] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/artists/search?q=\(encoded)")
    }
    
    func getOrCreateArtist(_ artist: CreateArtistDTO) async throws -> ArtistDTO {
        let response: ArtistDTO = try await client.post("/artists", body: artist)
        return response
    }

    func getArtist(with id: String) async throws -> ArtistDTO {
        let response: ArtistDTO = try await client.get("/artists/\(id)")
        return response
    }
}
