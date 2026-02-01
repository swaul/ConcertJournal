//
//  ConcertDetailViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import Combine
import Supabase
import Observation
import EventKit
import MapKit

@Observable
class ConcertDetailViewModel {
    
    var concert: FullConcertVisit
    let artist: Artist
    var imageUrls: [ConcertImage] = []

    private let photoRepository: PhotoRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol

    init(concert: FullConcertVisit, concertRepository: ConcertRepositoryProtocol, photoRepository: PhotoRepositoryProtocol) {
        self.concert = concert
        self.artist = concert.artist

        self.photoRepository = photoRepository
        self.concertRepository = concertRepository

        Task {
            do {
                try await loadImages()
            } catch {
                print("Failed to load images. Error: \(error)")
            }
        }
    }
    
    func loadImages() async throws {
        let photos: [ConcertPhoto] = try await photoRepository.fetchPhotos(for: concert.id)
        
        let urls = photos.compactMap { URL(string: $0.publicUrl) }.enumerated().map { (index, url) in
            ConcertImage(url: url, id: url.absoluteString, index: index)
        }
        
        imageUrls = urls
    }
    
    func createCalendarEntry(store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        
        let endDate = Calendar.current.date(byAdding: .hour, value: 3, to: concert.date)
        
        event.title = concert.title
        event.startDate = concert.date
        event.endDate = endDate
        event.notes = concert.notes
        if let venue = concert.venue, let latitude = venue.latitude, let longitude = venue.longitude {
            event.structuredLocation = EKStructuredLocation(mapItem: MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: MKAddress(fullAddress: venue.formattedAddress, shortAddress: nil)))
        } else {
            event.location = concert.venue?.formattedAddress
        }
        event.calendar = store.defaultCalendarForNewEvents
        
        return event
    }
    
    func applyUpdate(_ update: ConcertUpdate) async {
        // Create an updated model by keeping immutable fields and applying edits
        let updated = FullConcertVisit(
            id: concert.id,
            createdAt: concert.createdAt,
            updatedAt: Date(),
            date: update.date,
            venue: update.venue,
            city: update.city,
            rating: update.rating,
            title: update.title,
            notes: update.notes,
            artist: concert.artist
        )
        
        // Assign back to published state so UI updates
        self.concert = updated
        
        let dto = ConcertVisitUpdateDTO(update: update)
        
        do {
            try await concertRepository.updateConcert(id: concert.id, concert: dto)
        } catch {
            print("Update failed:", error)
            // optional: rollback
        }
    }
}
