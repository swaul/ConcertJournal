//
//  User.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

public struct Artist: Codable, Hashable, SupabaseEncodable {

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
    
    func encoded() -> [String: AnyJSON] {
        var data: [String: AnyJSON] = [
            CodingKeys.name.rawValue: .string(name),
            CodingKeys.imageUrl.rawValue: imageUrl != nil ? .string(imageUrl!) : .null,
            CodingKeys.spotifyArtistId.rawValue: spotifyArtistId != nil ? .string(spotifyArtistId!) : .null
        ]

        return data
    }
}
