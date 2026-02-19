//
//  Venue.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase

public struct VenueDTO: Sendable, nonisolated Codable, Equatable, Hashable {
    var id: String
    var name: String
    var city: String?
    var formattedAddress: String
    var latitude: Double?
    var longitude: Double?
    var appleMapsId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case formattedAddress = "formatted_address"
        case latitude
        case longitude
        case appleMapsId = "apple_maps_id"
    }
}
