//
//  VenueRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol VenueRepositoryProtocol {
    func createVenue(_ venue: VenueDTO) async throws -> String
}

class BFFVenueRepository: VenueRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func createVenue(_ venue: VenueDTO) async throws -> String {
        struct Response: Codable {
            let id: String
        }
        let response: Response = try await client.post("/venues", body: venue)
        return response.id
    }
}

struct IDResponse: Codable {
    let id: String
}
