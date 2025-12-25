//
//  Setlist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation

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
