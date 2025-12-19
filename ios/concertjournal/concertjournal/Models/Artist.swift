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
    let imageUrl: String
    let spotifyArtistId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case spotifyArtistId = "spotify_artist_id"
    }
}

public struct Photo: Codable {
    let id: String
    let concertVisitId: String
    let storagePath: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}

public struct ConcertVisit: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let userId: String
    let artistId: String
    let setlistId: String?
    let date: String
    let venue: String?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case setlistId = "setlist_id"
        case userId = "user_id"
        case artistId = "artist_id"
        case date
        case venue
        case city
        case notes
        case rating
        case title
    }
}

public struct Setlist: Codable {
    let id: String
    let createdAt: String
    let setlistItems: [SetlistItem]
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case setlistItems = "setlist_items"
    }
}

public struct SetlistItem: Codable {
    let id: String
    let concertVisitId: String
    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistName: String
    let notes: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case artistName = "artist_name"
        case notes
        case createdAt = "created_at"
    }
}

public struct FullConcertVisit: Codable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let updatedAt: Date
    public let date: Date
    public let venue: String?
    public let city: String?
    public let rating: Int?
    public let title: String?

    public let artist: Artist
    

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case date
        case venue
        case city
        case rating
        case title
        case artist = "artists"
    }
}
