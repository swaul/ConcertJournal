//
//  VenueRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol VenueRepositoryProtocol {
    func createVenue(_ venue: Venue) async throws -> String
}

public class VenueRepository: VenueRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager
    private let networkService: NetworkServiceProtocol

    init(supabaseClient: SupabaseClientManager, networkService: NetworkServiceProtocol) {
        self.supabaseClient = supabaseClient
        self.networkService = networkService
    }

    func createVenue(_ venue: Venue) async throws -> String {
        let venueId: String

        let existingVenueId: String?
        if let appleMapsId = venue.appleMapsId {
            // Get-or-create artist by spotify_artist_id (must match your DB column type)
            let existingVenue: [Venue] = try await supabaseClient.client
                .from("venues")
                .select()
                .eq("apple_maps_id", value: appleMapsId)
                .execute()
                .value

            existingVenueId = existingVenue.first?.id
        } else {
            let existingVenue: [Venue] = try await supabaseClient.client
                .from("venues")
                .select()
                .eq("name", value: venue.name)
                .execute()
                .value

            existingVenueId = existingVenue.first?.id
        }

        if let existingVenueId {
            venueId = existingVenueId
        } else {
            // Insert artist and prefer returning the inserted row to get canonical id
            let venueData = venue.encoded()
            let inserted: Venue = try await supabaseClient.client
                .from("venues")
                .insert(venueData)
                .select()
                .single()
                .execute()
                .value

            venueId = inserted.id
        }

        return venueId
    }
}
