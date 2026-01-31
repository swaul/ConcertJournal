//
//  Venue.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase

public struct Venue: Decodable, Equatable, Hashable, SupabaseEncodable {
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

    func encoded() -> [String: AnyJSON] {
        var data: [String: AnyJSON] = [
            "name": .string(name),
            "formatted_address": .string(formattedAddress)
        ]

        if let latitude {
            data["latitude"] = .double(latitude)
        } else {
            data["latitude"] = .null
        }
        if let longitude {
            data["longitude"] = .double(longitude)
        } else {
            data["longitude"] = .null
        }
        if let appleMapsId {
            data["apple_maps_id"] = .string(appleMapsId)
        } else {
            data["apple_maps_id"] = .null
        }

        return data
    }
}
