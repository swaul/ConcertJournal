//
//  NewConcert.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase
import Foundation

struct NewConcertDTO: SupabaseEncodable {
    let userId: String
    let artistId: String
    let date: String
    let venueId: String?
    let city: String?
    let notes: String
    let rating: Int
    let title: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case artistId = "artist_id"
        case date
        case venueId = "venue_id"
        case city
        case notes
        case rating
        case title
    }

    init(with new: NewConcertVisit, by userId: String, with artistId: String) {
        self.userId = userId
        self.artistId = artistId
        self.venueId = new.venue?.id
        self.city = new.venue?.city
        self.notes = new.notes
        self.rating = new.rating
        self.title = new.title

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: new.date)
        self.date = dateString
    }

    func encoded() throws -> [String: AnyJSON] {
        let encoded: [String: AnyJSON] = [
            CodingKeys.userId.rawValue: .string(userId),
            CodingKeys.artistId.rawValue: .string(artistId),
            CodingKeys.date.rawValue: .string(date),
            CodingKeys.rating.rawValue: .integer(rating),
            CodingKeys.title.rawValue: title.isEmpty ? .null : .string(title),
            CodingKeys.venueId.rawValue: venueId == nil ? .null : .string(venueId!),
            CodingKeys.city.rawValue: city == nil ? .null : .string(city!),
            CodingKeys.notes.rawValue: notes.isEmpty ? .null : .string(notes)
        ]

        return encoded
    }
}
