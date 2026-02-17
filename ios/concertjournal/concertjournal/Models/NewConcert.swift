//
//  NewConcert.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase
import Foundation

struct NewConcertDTO: Codable {
    let userId: String
    let artistId: String
    let supportActsIds: [String]
    let date: String
    let openingTime: String?
    let venueId: UUID?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case artistId = "artist_id"
        case supportActsIds = "support_acts_ids"
        case date
        case openingTime = "opening_time"
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

    init(with new: NewConcertVisit, supportActsIds: [String] = [], by userId: String, with artistId: String, travel: Travel? = nil) {
        self.userId = userId
        self.artistId = artistId
        self.supportActsIds = supportActsIds
        self.venueId = new.venue?.id
        self.city = new.venue?.city
        self.notes = new.notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.rating = new.rating
        self.title = new.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.date = new.date.supabseDateString
        self.openingTime = Self.correctedOpeningTime(openingTime: new.openingTime, date: new.date)?.supabseDateString
        self.travelType = travel?.travelType
        self.travelDuration = travel?.travelDuration
        self.travelDistance = travel?.travelDistance
        self.travelExpenses = travel?.travelExpenses
        self.hotelExpenses = travel?.hotelExpenses
    }

    static func correctedOpeningTime(openingTime: Date?, date: Date) -> Date? {
        guard let openingTime else { return nil }
        let calendar = Calendar.current
        let openingHourAndMinute = calendar.dateComponents([.hour, .minute], from: openingTime)
        guard let hour = openingHourAndMinute.hour,
              let minute = openingHourAndMinute.minute else { return openingTime }

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? openingTime
    }
}

struct CreateConcertDTO {
    let userId: String
    let artistId: String
    let supportActsIds: [ArtistDTO]
    let date: Date
    let openingTime: Date?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    let venue: VenueDTO?

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: Price?
    let hotelExpenses: Price?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case artistId = "artist_id"
        case supportActsIds = "support_acts_ids"
        case date
        case openingTime = "opening_time"
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
