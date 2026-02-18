//
//  NewConcert.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase
import Foundation
import UIKit

struct CreateConcertDTO {

    let artist: ArtistDTO
    let supportActs: [ArtistDTO]
    let date: Date
    let openingTime: Date?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    let venue: VenueDTO?

    // Travel
    let travel: TravelDTO?
    let ticket: TicketDTO?
    let images: [UIImage]

    init?(newConcertVisit: NewConcertVisit, images: [UIImage]) {
        guard let artist = newConcertVisit.artist else { return nil }
        self.artist = artist
        self.supportActs = newConcertVisit.supportActs
        self.date = newConcertVisit.date
        self.openingTime = newConcertVisit.openingTime
        self.city = newConcertVisit.venue?.city
        self.notes = newConcertVisit.notes
        self.rating = newConcertVisit.rating
        self.title = newConcertVisit.title
        self.venue = newConcertVisit.venue
        self.travel = newConcertVisit.travel
        self.ticket = newConcertVisit.ticket
        self.images = images
    }
}
