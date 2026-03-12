//
//  SyncModels.swift
//  concertjournal
//
//  Created by Paul Arbetit on 12.03.26.
//

import Foundation
import CoreData

// MARK: - Push Payload

struct ConcertPushPayload: Encodable {
    let serverId: String?
    var title: String?
    let date: Date
    let openingTime: Date?
    var notes: String?
    let rating: Int?
    let city: String?
    let version: Int
    var buddyAttendees: [BuddyAttendee]
    
    let artist: ArtistDTO
    var artistServerId: String?
    var venueServerId: String?
    let venue: VenueDTO?
    var supportActServerIds: [String]?
    let supportActs: [ArtistDTO]?
    
    var tourServerId: String?
    let tour: TourDTO?
    
    let travelType: String?
    let travelDuration: Double?
    let travelDistance: Double?
    let arrivedAt: Date?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?
    
    let ticketType: String?
    let ticketCategory: String?
    let ticketPrice: PriceDTO?
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?
    let standingPosition: String?
    var ticketNotes: String?
    
    private enum CodingKeys: String, CodingKey {
        case date, city, notes, rating, title, version
        case buddyAttendees = "buddy_attendees"
        case serverId = "id"
        case venueServerId = "venue_id"
        case artistServerId = "artist_id"
        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
        case ticketPrice = "ticket_price"
        case openingTime = "opening_time"
        case arrivedAt = "arrived_at"
        case tourId = "tour_id"
        case supportActServerIds = "support_acts_ids"
    }
    
    init(concert: Concert) {
        serverId    = concert.serverId
        title       = concert.title
        date        = concert.date
        openingTime = concert.openingTime
        notes       = concert.notes
        rating      = concert.rating == 0 ? nil : Int(concert.rating)
        city        = concert.city
        version     = Int(concert.syncVersion)
        buddyAttendees = concert.buddiesArray
        
        artistServerId  = concert.artist.serverId
        artist = concert.artist.toDTO()
        venueServerId   = concert.venue?.serverId
        venue = concert.venue?.toDTO()
        
        supportActs = concert.supportActsArray.compactMap { $0.toDTO() }
        supportActServerIds = concert.supportActsArray
            .compactMap { $0.serverId }
        
        tour = concert.tour?.toDTO()
        tourServerId = concert.tour?.serverId
        
        travelType     = concert.travel?.travelType
        travelDuration = concert.travel?.travelDuration
        travelDistance = concert.travel?.travelDistance
        arrivedAt      = concert.travel?.arrivedAt
        travelExpenses = concert.travel?.travelExpenses
        hotelExpenses = concert.travel?.hotelExpenses
        
        ticketType     = concert.ticket?.ticketType
        ticketCategory = concert.ticket?.ticketCategory
        seatBlock      = concert.ticket?.seatBlock
        seatRow        = concert.ticket?.seatRow
        seatNumber     = concert.ticket?.seatNumber
        standingPosition = concert.ticket?.standingPosition
        ticketNotes    = concert.ticket?.notes
        ticketPrice    = concert.ticket?.ticketPrice
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.serverId, forKey: .serverId)
        try container.encode(self.date.supabseDateString, forKey: .date)
        try container.encodeIfPresent(self.city, forKey: .city)
        try container.encodeIfPresent(self.notes, forKey: .notes)
        try container.encodeIfPresent(self.rating, forKey: .rating)
        try container.encodeIfPresent(self.title, forKey: .title)
        try container.encode(self.version, forKey: .version)
        try container.encodeIfPresent(self.buddyAttendees, forKey: .buddyAttendees)
        try container.encodeIfPresent(self.venueServerId, forKey: .venueServerId)
        try container.encodeIfPresent(self.artistServerId, forKey: .artistServerId)
        try container.encodeIfPresent(self.travelType, forKey: .travelType)
        try container.encodeIfPresent(self.travelDuration, forKey: .travelDuration)
        try container.encodeIfPresent(self.travelDistance, forKey: .travelDistance)
        try container.encodeIfPresent(self.travelExpenses, forKey: .travelExpenses)
        try container.encodeIfPresent(self.hotelExpenses, forKey: .hotelExpenses)
        try container.encodeIfPresent(self.ticketType, forKey: .ticketType)
        try container.encodeIfPresent(self.ticketCategory, forKey: .ticketCategory)
        try container.encodeIfPresent(self.seatBlock, forKey: .seatBlock)
        try container.encodeIfPresent(self.seatRow, forKey: .seatRow)
        try container.encodeIfPresent(self.seatNumber, forKey: .seatNumber)
        try container.encodeIfPresent(self.standingPosition, forKey: .standingPosition)
        try container.encodeIfPresent(self.ticketNotes, forKey: .ticketNotes)
        try container.encodeIfPresent(self.ticketPrice, forKey: .ticketPrice)
        try container.encodeIfPresent(self.openingTime?.supabseDateString, forKey: .openingTime)
        try container.encodeIfPresent(self.arrivedAt?.supabseDateString, forKey: .arrivedAt)
        try container.encodeIfPresent(self.tourServerId, forKey: .tourId)
        try container.encodeIfPresent(self.supportActServerIds, forKey: .supportActServerIds)
    }
}

// MARK: - Sync Helper Structs

struct ConcertSyncInfo {
    let objectID: NSManagedObjectID
    let syncStatus: String
    let serverId: String?
}

// MARK: - Errors

enum SyncError: Error {
    case missingServerId
    case UploadFailedFor(String)
    case contextMismatch
}

// MARK: - Server Models

struct ServerConcert: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date?
    let userId: String
    let artistId: String?
    let date: Date
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    let buddyAttendees: [BuddyAttendee]?
    let venueId: String?
    let travelType: String?
    let travelDuration: Double?
    let travelDistance: Double?
    let travelExpenses: PriceDTO?
    let hotelExpenses: PriceDTO?
    let ticketType: String?
    let ticketCategory: String?
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?
    let standingPosition: String?
    let ticketNotes: String?
    let ticketPrice: PriceDTO?
    let openingTime: Date?
    let arrivedAt: Date?
    let tourId: String?
    let supportActsIds: [String]?
    let deletedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id, date, city, notes, rating, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case artistId = "artist_id"
        case venueId = "venue_id"
        case buddyAttendees = "buddy_attendees"
        case travelType = "travel_type"
        case travelDuration = "travel_duration"
        case travelDistance = "travel_distance"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
        case ticketType = "ticket_type"
        case ticketCategory = "ticket_category"
        case seatBlock = "seat_block"
        case seatRow = "seat_row"
        case seatNumber = "seat_number"
        case standingPosition = "standing_position"
        case ticketNotes = "ticket_notes"
        case ticketPrice = "ticket_price"
        case openingTime = "opening_time"
        case arrivedAt = "arrived_at"
        case tourId = "tour_id"
        case supportActsIds = "support_acts_ids"
        case deletedAt = "deleted_at"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        self.buddyAttendees = try container.decodeIfPresent([BuddyAttendee].self, forKey: .buddyAttendees)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.venueId = try container.decodeIfPresent(String.self, forKey: .venueId)
        self.travelType = try container.decodeIfPresent(String.self, forKey: .travelType)
        self.travelDuration = try container.decodeIfPresent(Double.self, forKey: .travelDuration)
        self.travelDistance = try container.decodeIfPresent(Double.self, forKey: .travelDistance)
        self.travelExpenses = try container.decodeIfPresent(PriceDTO.self, forKey: .travelExpenses)
        self.hotelExpenses = try container.decodeIfPresent(PriceDTO.self, forKey: .hotelExpenses)
        self.ticketType = try container.decodeIfPresent(String.self, forKey: .ticketType)
        self.ticketCategory = try container.decodeIfPresent(String.self, forKey: .ticketCategory)
        self.seatBlock = try container.decodeIfPresent(String.self, forKey: .seatBlock)
        self.seatRow = try container.decodeIfPresent(String.self, forKey: .seatRow)
        self.seatNumber = try container.decodeIfPresent(String.self, forKey: .seatNumber)
        self.standingPosition = try container.decodeIfPresent(String.self, forKey: .standingPosition)
        self.ticketNotes = try container.decodeIfPresent(String.self, forKey: .ticketNotes)
        self.ticketPrice = try container.decodeIfPresent(PriceDTO.self, forKey: .ticketPrice)
        self.supportActsIds = try container.decodeIfPresent([String].self, forKey: .supportActsIds)
        self.tourId = try container.decodeIfPresent(String.self, forKey: .tourId)
        
        if let createdAt = try container.decode(String.self, forKey: .createdAt).supabaseStringDate {
            self.createdAt = createdAt
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.createdAt], debugDescription: "Created at missing"))
        }
        if let updatedAt = try container.decode(String.self, forKey: .updatedAt).supabaseStringDate {
            self.updatedAt = updatedAt
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.updatedAt], debugDescription: "Updated at missing"))
        }
        if let date = try container.decode(String.self, forKey: .date).supabaseStringDate {
            self.date = date
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.updatedAt], debugDescription: "Date at missing"))
        }
        if let openingTime = try container.decodeIfPresent(String.self, forKey: .openingTime)?.supabaseStringDate {
            self.openingTime = openingTime
        } else {
            self.openingTime = nil
        }
        if let arrivedAt = try container.decodeIfPresent(String.self, forKey: .arrivedAt)?.supabaseStringDate {
            self.arrivedAt = arrivedAt
        } else {
            self.arrivedAt = nil
        }
        if let deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)?.supabaseStringDate {
            self.deletedAt = deletedAt
        } else {
            self.deletedAt = nil
        }
    }
}

enum SyncingProblem {
    case decryptionFailed
}
