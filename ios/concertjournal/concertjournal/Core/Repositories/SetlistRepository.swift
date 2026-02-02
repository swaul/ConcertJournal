//
//  SetlistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import Foundation
import Supabase

protocol SetlistRepositoryProtocol {
    func createSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem
    func getSetlistItems(with concertId: String) async throws -> [SetlistItem]
    func deleteSetlistItem(_ setlistItemId: String) async throws
}

public class SetlistRepository: SetlistRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager
    private let networkService: NetworkServiceProtocol

    init(supabaseClient: SupabaseClientManager, networkService: NetworkServiceProtocol) {
        self.supabaseClient = supabaseClient
        self.networkService = networkService
    }

    func createSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem {
        let inserted: SetlistItem = try await supabaseClient.client
            .from("setlist_items")
            .insert(setlistItem.encoded())
            .select()
            .single()
            .execute()
            .value

        return inserted
    }

    func getSetlistItems(with concertId: String) async throws -> [SetlistItem] {
        try await supabaseClient.client
            .from("setlist_songs")
            .select()
            .eq("concert_visit_id", value: concertId)
            .order("position", ascending: true)
            .execute()
            .value
    }

    func deleteSetlistItem(_ setlistItemId: String) async throws {
        try await networkService.delete(from: "setlist_items", id: setlistItemId)
    }
}
