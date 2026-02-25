//
//  NewConcert.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Supabase
import Foundation
import UIKit
import CoreData

struct CreateConcertDTO {

    let id: UUID
    let artist: ArtistDTO
    let supportActs: [ArtistDTO]
    let date: Date
    let openingTime: Date?
    let city: String?
    let notes: String?
    let rating: Int?
    let title: String?
    let venue: VenueDTO?
    let setlistItems: [TempCeateSetlistItem]

    let tour: NSManagedObjectID?
    let travel: TravelDTO?
    let ticket: TicketDTO?
    let images: [UIImage]

    init?(newConcertVisit: NewConcertVisit, images: [UIImage]) {
        guard let artist = newConcertVisit.artist else { return nil }
        self.id = UUID()
        self.artist = artist
        self.supportActs = newConcertVisit.supportActs
        self.date = newConcertVisit.date
        self.openingTime = newConcertVisit.openingTime
        self.city = newConcertVisit.venue?.city
        self.notes = newConcertVisit.notes
        self.rating = newConcertVisit.rating
        self.title = newConcertVisit.title
        self.venue = newConcertVisit.venue
        self.tour = newConcertVisit.tour
        self.travel = newConcertVisit.travel
        self.ticket = newConcertVisit.ticket
        self.setlistItems = newConcertVisit.setlistItems

        self.images = images
    }
}
