//
//  SetlistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import Foundation
import Supabase

protocol SetlistRepositoryProtocol {
    func getOrCreateSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem
    func createSetlist(_ setlist: CreateSetlistDTO) async throws -> Setlist
}

public class SetlistRepository: SetlistRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager
    private let networkService: NetworkServiceProtocol

    init(supabaseClient: SupabaseClientManager, networkService: NetworkServiceProtocol) {
        self.supabaseClient = supabaseClient
        self.networkService = networkService
    }

    func getOrCreateSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem {
        if setlistItem.spotifyTrackId != nil {
            let upserted: SetlistItem = try await supabaseClient.client
                .from("setlist_items")
                .upsert(setlistItem.encoded(), onConflict: "spotify_artist_id")
                .select()
                .single()
                .execute()
                .value

            return upserted
        }

        return try await createSetlistItem(setlistItem)
    }

    private func createSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem {
        let inserted: SetlistItem = try await supabaseClient.client
            .from("setlist_items")
            .insert(setlistItem.encoded())
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    func createSetlist(_ setlist: CreateSetlistDTO) async throws -> Setlist {
        let inserted: Setlist = try await supabaseClient.client
            .from("setlist")
            .insert(setlist.encoded())
            .select()
            .single()
            .execute()
            .value

        return inserted
    }
}
