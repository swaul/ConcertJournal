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
    var setlistItems: [SetlistItem]? = nil
    var errorMessage: String?
    var loadingSetlist: Bool = false

    private let photoRepository: PhotoRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol

    init(concert: FullConcertVisit, concertRepository: ConcertRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol, photoRepository: PhotoRepositoryProtocol) {
        self.concert = concert
        self.artist = concert.artist

        self.photoRepository = photoRepository
        self.setlistRepository = setlistRepository
        self.concertRepository = concertRepository

        Task {
            try? await loadImages()
            do {
                loadingSetlist = true
                try await loadSetlist()
                loadingSetlist = false
            } catch {
                print(error)
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

    func loadSetlist() async throws {
        let setlistItems: [SetlistItem] = try await setlistRepository.getSetlistItems(with: concert.id)

        self.setlistItems = setlistItems
        self.concert.setlistItems = setlistItems
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
        let concertDTO = ConcertVisitUpdateDTO(update: update)

        do {
            try await concertRepository.updateConcert(id: concert.id, concert: concertDTO)
        } catch {
            print("Concert Update failed:", error)
        }
        
        do {
            if let setlistItems = update.setlistItems {
                let setlistDTOs = setlistItems.map { UpdateSetlistItemDTO(concertId: update.id, item: $0) }
                for setlistDTO in setlistDTOs {
                    try await setlistRepository.updateSetlistItem(setlistDTO)
                }
            }
        } catch {
            print("Setlist Update failed:", error)
        }
        
        do {
            let concert: FullConcertVisit = try await concertRepository.getConcert(id: concert.id)
            let setlistItems: [SetlistItem] = try await setlistRepository.getSetlistItems(with: concert.id)
            self.concert = concert
            self.concert.setlistItems = setlistItems
            self.setlistItems = setlistItems
        } catch {
            print("Reload concert failed:", error)
        }
    }

    func deleteConcert() async throws {
        try await concertRepository.deleteConcert(id: concert.id)
        try await concertRepository.reloadConcerts()
    }

}
