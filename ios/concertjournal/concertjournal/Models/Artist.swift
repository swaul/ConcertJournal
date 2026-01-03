//
//  User.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

public struct Artist: Codable {
    
    let id: String
    let name: String
    let imageUrl: String?
    let spotifyArtistId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case spotifyArtistId = "spotify_artist_id"
    }
    
    init(artist: SpotifyArtist) {
        id = UUID().uuidString
        name = artist.name
        imageUrl = artist.firstImageURL?.absoluteString
        spotifyArtistId = artist.id
    }
    
    init(name: String, imageUrl: String? = nil, spotifyArtistId: String?) {
        self.id = UUID().uuidString
        self.name = name
        self.imageUrl = imageUrl
        self.spotifyArtistId = spotifyArtistId
    }
    
    var toData: [String: AnyJSON] {
        var data: [String: AnyJSON] = [
            "name": .string(name),
        ]
        
        if let imageUrl {
            data["image_url"] = .string(imageUrl)
        } else {
            data["image_url"] = .null
        }
        if let spotifyArtistId {
            data["spotify_artist_id"] = .string(spotifyArtistId)
        } else {
            data["spotify_artist_id"] = .null
        }
        
        return data
    }
}
