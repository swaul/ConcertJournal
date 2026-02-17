//
//  ConcertVisit.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation
import Supabase


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
    public let openingTimeString: String?
    public let venue: VenueDTO?
    public let city: String?
    public let rating: Int?
    public let title: String?
    public let notes: String?

    public let artist: ArtistDTO
    public let supportActsIds: [String]?
    public var supportActs: [ArtistDTO]?
    public var setlistItems: [SetlistItemDTO]?

    var createdAt: Date? {
        createdAtString.supabaseStringDate
    }
    
    var updatedAt: Date? {
        updatedAtString.supabaseStringDate
    }
    
    var date: Date {
        dateString.supabaseStringDate ?? Date.now
    }

    var openingTime: Date? {
        openingTimeString?.supabaseStringDate
    }

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let arrivedAtString: String?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?

    var arrivedAt: Date? {
        arrivedAtString?.supabaseStringDate
    }

    var travel: TravelDTO? {
        TravelDTO(travelType: travelType, travelDuration: travelDuration, travelDistance: travelDistance, arrivedAt: arrivedAt, travelExpenses: travelExpenses, hotelExpenses: hotelExpenses)
    }

    let ticketType: TicketType?
    let ticketCategory: TicketCategory?
    let ticketPrice: PriceDTO?

    // Seated Ticket Info
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?

    // Standing Ticket info
    let standingPosition: String?

    let ticketNotes: String?

    var ticket: TicketDTO? {
        guard let ticketType = ticketType, let ticketCategory = ticketCategory else { return nil }
        return TicketDTO(ticketType: ticketType, ticketCategory: ticketCategory, ticketPrice: ticketPrice, seatBlock: seatBlock, seatRow: seatRow, seatNumber: seatNumber, standingPosition: standingPosition, notes: ticketNotes)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtString = "created_at"
        case updatedAtString = "updated_at"
        case dateString = "date"
        case openingTimeString = "opening_time"
        case venue = "venues"
        case city
        case rating
        case notes
        case title
        case artist = "artists"
        case supportActsIds = "support_acts_ids"

        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case arrivedAtString = "arrived_at"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"

        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case ticketPrice = "ticket_price"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
    }
}

public struct PartialConcertVisit: Decodable, Identifiable, Equatable, Hashable {

    public let id: String
    public let dateString: String
    public let openingTimeString: String?
    public let venue: VenueDTO?
    public let artist: ArtistDTO
    public let city: String?
    public let title: String?
    public let rating: Int?

    var date: Date {
        dateString.supabaseStringDate ?? Date.now
    }

    var openingTime: Date? {
        openingTimeString?.supabaseStringDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case dateString = "date"
        case openingTimeString = "opening_time"
        case venue = "venue"
        case city
        case title
        case artist = "artist"
        case rating
    }
}

public struct ConcertDetails: Decodable {
    let id: String
    let dateString: String
    let openingTimeString: String?

    var date: Date {
        dateString.supabaseStringDate ?? Date.now
    }

    var openingTime: Date? {
        openingTimeString?.supabaseStringDate
    }

    // Travel
    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let arrivedAtString: String?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?

    var arrivedAt: Date? {
        arrivedAtString?.supabaseStringDate
    }

    // Ticket
    let ticketType: TicketType?
    let ticketCategory: TicketCategory?
    let ticketPrice: PriceDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case dateString = "date"
        case openingTimeString = "opening_time"

        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case arrivedAtString = "arrived_at"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"

        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case ticketPrice = "ticket_price"
    }
}
