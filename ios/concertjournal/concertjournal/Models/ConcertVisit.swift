//
//  ConcertVisit.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation
import Supabase

public struct ConcertVisit: Decodable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let userId: String
    let artistId: String
    let date: String
    let venueId: String?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: Price?
    let hotelExpenses: Price?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case artistId = "artist_id"
        case date
        case venueId = "venue_id"
        case city
        case notes
        case rating
        case title
        
        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
    }
}

public struct FullConcertVisit: Decodable, Identifiable, Equatable, Hashable {

    public static func == (lhs: FullConcertVisit, rhs: FullConcertVisit) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public let id: String
    public let createdAtString: String
    public let updatedAtString: String
    public let dateString: String
    public let venue: Venue?
    public let city: String?
    public let rating: Int?
    public let title: String?
    public let notes: String?

    public let artist: Artist
    public var setlistItems: [SetlistItem]?
    
    var createdAt: Date? {
        createdAtString.supabaseStringDate
    }
    
    var updatedAt: Date? {
        updatedAtString.supabaseStringDate
    }
    
    var date: Date {
        dateString.supabaseStringDate ?? Date.now
    }

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: Price?
    let hotelExpenses: Price?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtString = "created_at"
        case updatedAtString = "updated_at"
        case dateString = "date"
        case venue = "venues"
        case city
        case rating
        case notes
        case title
        case artist = "artists"

        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
    }
}
