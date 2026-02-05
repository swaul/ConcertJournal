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
    func updateSetlistItem(_ item: UpdateSetlistItemDTO) async throws
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
    
    func updateSetlistItem(_ item: UpdateSetlistItemDTO) async throws {
        if let id = item.id {
            let _: SetlistItem = try await client.patch("/setlist/\(id)", body: item)
        } else {
            _ = try await createSetlistItem(item.createSetlistItem)
        }
    }
    
    func deleteSetlistItem(_ itemId: String) async throws {
        try await client.delete("/setlist/\(itemId)")
    }
}
