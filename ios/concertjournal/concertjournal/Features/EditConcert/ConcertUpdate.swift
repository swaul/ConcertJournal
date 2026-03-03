//
//  ConcertUpdate.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import Foundation

struct ConcertUpdate {
    let id: UUID
    let title: String?
    let date: Date
    let openingTime: Date?
    let notes: String?
    let venue: VenueDTO?
    let city: String?
    let rating: Int?
    let tour: Tour?

    let buddyAttendees: [BuddyAttendee]?
    let travel: TravelDTO?
    let ticket: TicketDTO?
    let supportActs: [ArtistDTO]?
    let setlistItems: [TempCeateSetlistItem]?
    let photos: [ConcertPhoto]
}
