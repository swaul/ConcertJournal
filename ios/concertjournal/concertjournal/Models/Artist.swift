//
//  User.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

public struct Artist: Codable, Hashable, Identifiable {

    public let id: String
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
}

public struct CreateArtistDTO: Encodable {
    let name: String
    let imageUrl: String?
    let spotifyArtistId: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case imageUrl = "image_url"
        case spotifyArtistId = "spotify_artist_id"
    }
    
    init(artist: Artist) {
        name = artist.name
        imageUrl = artist.imageUrl
        spotifyArtistId = artist.spotifyArtistId
    }
}
