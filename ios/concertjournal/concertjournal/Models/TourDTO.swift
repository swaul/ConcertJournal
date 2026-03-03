//
//  TourDTO.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import Foundation

public struct TourDTO: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let tourDescription: String?
    public let startDate: String
    public let endDate: String
    public let artistId: String
    public let ownerId: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tourDescription = "tourDescription"
        case startDate = "start_date"
        case endDate = "end_date"
        case artistId = "artist_id"
        case ownerId = "owner_id"
    }
}

public struct FullTourVisit: Decodable, Identifiable {
    public let id: String
    public let name: String
    public let tourDescription: String?
    public let startDateString: String
    public let endDateString: String
    public let artist: ArtistDTO?
    public let concerts: [PartialConcertVisit]?

    var startDate: Date {
        startDateString.supabaseStringDate ?? Date.now
    }

    var endDate: Date {
        endDateString.supabaseStringDate ?? Date.now
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tourDescription = "tourDescription"
        case startDateString = "start_date"
        case endDateString = "end_date"
        case artist
        case concerts
    }
}
