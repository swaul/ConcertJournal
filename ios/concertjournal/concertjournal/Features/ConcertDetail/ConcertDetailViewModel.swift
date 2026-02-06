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
        let startTime = Date()

        // 1. Detect Changes
        let (changes, optimizedDTO) = concert.detectChanges(from: update)

        // 2. Early Return wenn keine Changes
        guard changes.hasAnyChanges else {
            logInfo("No changes detected", category: .concert)
            return
        }

        logInfo("Changes: \(changes.changedFields.joined(separator: ", "))", category: .concert)

        // 3. Update Concert (nutzt die EINE updateConcert Methode)
        if changes.hasBasicChanges || changes.hasTravelChanges || changes.hasTicketChanges {
            do {
                // ✅ Gleiche Methode, verschiedene DTOs möglich
                if optimizedDTO.isEmpty {
                    logDebug("No concert fields to update", category: .concert)
                } else {
                    // Sende optimizedDTO (nur geänderte Felder)
                    try await concertRepository.updateConcert(
                        id: concert.id,
                        concert: optimizedDTO
                    )
                    logSuccess("Concert updated", category: .concert)
                }
            } catch {
                logError("Update failed", error: error, category: .concert)
                return
            }
        }

        // 4. Update Setlist
        if changes.hasSetlistChanges, let items = update.setlistItems {
            do {
                try await updateSetlistItems(items)
                logSuccess("Setlist updated", category: .setlist)
            } catch {
                logError("Setlist update failed", error: error, category: .setlist)
            }
        }

        // 5. Reload
        await reloadConcertData()

        let duration = Date().timeIntervalSince(startTime)
        logSuccess("Update completed in \(String(format: "%.2f", duration))s", category: .concert)
    }

    // Helper für Setlist Updates
    private func updateSetlistItems(_ items: [TempCeateSetlistItem]) async throws {
        let dtos = items.map { UpdateSetlistItemDTO(concertId: concert.id, item: $0) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for dto in dtos {
                group.addTask {
                    try await self.setlistRepository.updateSetlistItem(dto)
                }
            }
            try await group.waitForAll()
        }
    }

    // Helper für Reload
    private func reloadConcertData() async {
        do {
            async let concertFetch = concertRepository.getConcert(id: concert.id)
            async let setlistFetch = setlistRepository.getSetlistItems(with: concert.id)

            let (fetchedConcert, fetchedSetlist) = try await (concertFetch, setlistFetch)

            self.concert = fetchedConcert
            self.concert.setlistItems = fetchedSetlist
            self.setlistItems = fetchedSetlist
        } catch {
            logError("Reload failed", error: error, category: .concert)
        }
    }
    func deleteConcert() async throws {
        try await concertRepository.deleteConcert(id: concert.id)
        try await concertRepository.reloadConcerts()
    }

}
