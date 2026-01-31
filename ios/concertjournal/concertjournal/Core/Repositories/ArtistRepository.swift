//
//  ArtistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol ArtistRepositoryProtocol {
    func getOrCreateArtist(_ artist: Artist) async throws -> String
}

public class ArtistRepository: ArtistRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager
    private let networkService: NetworkServiceProtocol

    init(supabaseClient: SupabaseClientManager, networkService: NetworkServiceProtocol) {
        self.supabaseClient = supabaseClient
        self.networkService = networkService
    }

    func getOrCreateArtist(_ artist: Artist) async throws -> String {
        if let existingId = try await findExistingArtist(artist) {
            return existingId
        }

        return try await createArtist(artist)
    }


    private func findExistingArtist(_ artist: Artist) async throws -> String? {
        if let spotifyId = artist.spotifyArtistId {
            let artists: [Artist] = try await supabaseClient.client
                .from("artists")
                .select()
                .eq("spotify_artist_id", value: spotifyId)
                .limit(1)
                .execute()
                .value

            if let existingArtist = artists.first {
                return existingArtist.id
            }
        }

        let artists: [Artist] = try await supabaseClient.client
            .from("artists")
            .select()
            .eq("name", value: artist.name)
            .limit(1)
            .execute()
            .value

        return artists.first?.id
    }

    private func createArtist(_ artist: Artist) async throws -> String {
        let inserted: Artist = try await supabaseClient.client
            .from("artists")
            .insert(artist.encoded())
            .select()
            .single()
            .execute()
            .value

        return inserted.id
    }

    func searchArtists(query: String) async throws -> [Artist] {
        return try await supabaseClient.client
            .from("artists")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
    }

    func fetchArtist(id: String) async throws -> Artist {
        return try await supabaseClient.client
            .from("artists")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}
