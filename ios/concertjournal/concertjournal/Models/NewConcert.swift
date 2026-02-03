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

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: Price?
    let hotelExpenses: Price?

    enum CodingKeys: String, CodingKey {
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

    init(with new: NewConcertVisit, by userId: String, with artistId: String, travel: Travel? = nil) {
        self.userId = userId
        self.artistId = artistId
        self.venueId = new.venue?.id
        self.city = new.venue?.city
        self.notes = new.notes
        self.rating = new.rating
        self.title = new.title
        self.date = new.date.supabseDateString
        self.travelType = travel?.travelType
        self.travelDuration = travel?.travelDuration
        self.travelDistance = travel?.travelDistance
        self.travelExpenses = travel?.travelExpenses
        self.hotelExpenses = travel?.hotelExpenses
    }

    func encoded() throws -> [String: AnyJSON] {
        var encoded: [String: AnyJSON] = [
            CodingKeys.userId.rawValue: .string(userId),
            CodingKeys.artistId.rawValue: .string(artistId),
            CodingKeys.date.rawValue: .string(date),
            CodingKeys.rating.rawValue: .integer(rating),
            CodingKeys.title.rawValue: title.isEmpty ? .null : .string(title),
            CodingKeys.venueId.rawValue: venueId == nil ? .null : .string(venueId!),
            CodingKeys.city.rawValue: city == nil ? .null : .string(city!),
            CodingKeys.notes.rawValue: notes.isEmpty ? .null : .string(notes),
            CodingKeys.travelType.rawValue: travelType == nil ? .null : .string(travelType!.rawValue),
            CodingKeys.travelDuration.rawValue: travelDuration == nil ? .null : .double(travelDuration!),
            CodingKeys.travelDistance.rawValue: travelDistance == nil ? .null : .double(travelDistance!),
            CodingKeys.travelExpenses.rawValue: .null,
            CodingKeys.hotelExpenses.rawValue: .null
        ]

        if let travelExpenses, let travelExpensesEncoded = try? travelExpenses.encoded() {
            encoded[CodingKeys.travelExpenses.rawValue] = .object(travelExpensesEncoded)
        }

        if let hotelExpenses, let hotelExpensesEncoded = try? hotelExpenses.encoded() {
            encoded[CodingKeys.hotelExpenses.rawValue] = .object(hotelExpensesEncoded)
        }


        return encoded
    }
}
