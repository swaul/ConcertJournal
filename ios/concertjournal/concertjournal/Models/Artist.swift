//
//  User.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation

public struct Artist: Codable {
    let id: String
    let name: String
    let imageUrl: String?
    let spotifyArtistId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case spotifyArtistId = "spotify_artist_id"
    }
}
