//
//  SetlistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import Foundation
import Supabase

protocol SetlistRepositoryProtocol {
    func getSetlistItems(with concertId: String) async throws -> [SetlistItem]
    func createSetlistItem(_ item: CreateSetlistItemDTO) async throws -> SetlistItem
    func deleteSetlistItem(_ itemId: String) async throws
}

class BFFSetlistRepository: SetlistRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func getSetlistItems(with concertId: String) async throws -> [SetlistItem] {
        try await client.get("/setlist/\(concertId)")
    }
    
    func createSetlistItem(_ item: CreateSetlistItemDTO) async throws -> SetlistItem {
        try await client.post("/setlist/\(item.concertVisitId)/songs", body: item)
    }
    
    func deleteSetlistItem(_ itemId: String) async throws {
        try await client.delete("/setlist/songs/\(itemId)")
    }
}
