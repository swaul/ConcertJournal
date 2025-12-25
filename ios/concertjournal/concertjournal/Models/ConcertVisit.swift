//
//  ConcertVisit.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation

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
