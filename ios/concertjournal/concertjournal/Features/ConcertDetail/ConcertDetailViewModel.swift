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
    var supportActs: [Artist]? = nil
    var errorMessage: String?
    var successMessage: String? = nil
    var createdPlaylistURL: String? = nil
    
    var isLoading: Bool = true

    private let client: BFFClient
    private let photoRepository: PhotoRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol
    private let artistRepository: ArtistRepositoryProtocol

    init(concert: FullConcertVisit, bffClient: BFFClient, concertRepository: ConcertRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol, photoRepository: PhotoRepositoryProtocol, artistRepository: ArtistRepositoryProtocol) {
        self.concert = concert
        self.artist = concert.artist

        self.client = bffClient
        self.photoRepository = photoRepository
        self.setlistRepository = setlistRepository
        self.concertRepository = concertRepository
        self.artistRepository = artistRepository

        Task {
            try? await loadImages()
            do {
                async let setlistTask: Void = loadSetlist()
                async let supportActsTask: Void = loadSupportActs()

                _ = try? await (supportActsTask, setlistTask)
                isLoading = false
            } catch {
                isLoading = false
                HapticManager.shared.error()
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

    func loadSupportActs() async throws {
        guard let supportActs = concert.supportActsIds else { return }
        var loadedSupoprtActs: [Artist] = []
        for id in supportActs {
            let supportAct: Artist = try await artistRepository.getArtist(with: id)
            loadedSupoprtActs.append(supportAct)
        }

        self.supportActs = loadedSupoprtActs
        self.concert.supportActs = loadedSupoprtActs
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

        let (changes, optimizedDTO) = concert.detectChanges(from: update)

        guard changes.hasAnyChanges else {
            logInfo("No changes detected", category: .concert)
            return
        }

        logInfo("Changes: \(changes.changedFields.joined(separator: ", "))", category: .concert)

        if changes.hasBasicChanges || changes.hasTravelChanges || changes.hasTicketChanges {
            do {
                if optimizedDTO.isEmpty {
                    logDebug("No concert fields to update", category: .concert)
                } else {
                    try await concertRepository.updateConcert(
                        id: concert.id,
                        concert: optimizedDTO
                    )
                    logSuccess("Concert updated", category: .concert)
                }
            } catch {
                logError("Update failed", error: error, category: .concert)
                HapticManager.shared.error()
                return
            }
        }

        if changes.hasSetlistChanges, let items = update.setlistItems {
            do {
                if let currentSetlistItems = setlistItems {
                    let currentIDs = Set(currentSetlistItems.map(\.id))
                    let newIDs = Set(items.compactMap(\.existingItemid))
                    
                    let idsToDelete = currentIDs.subtracting(newIDs)
                    
                    for id in idsToDelete {
                        try await setlistRepository.deleteSetlistItem(id)
                        logSuccess("Setlist updated. Removed item with id \(id)", category: .setlist)
                    }
                }
                
                try await updateSetlistItems(items)

                logSuccess("Setlist updated", category: .setlist)
            } catch {
                logError("Setlist update failed", error: error, category: .setlist)
                HapticManager.shared.error()
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
            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
            logError("Reload failed", error: error, category: .concert)
        }
    }
    func deleteConcert() async throws {
        try await concertRepository.deleteConcert(id: concert.id)
        HapticManager.shared.success()
    }

    @MainActor
    func createSpotifyPlaylist(spotifyRepository: SpotifyRepositoryProtocol, userSessionManager: UserSessionManagerProtocol) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        logInfo("Creating Spotify playlist from setlist", category: .viewModel)

        do {
            // Build playlist name
            let playlistName = "Setlist von \(concert.artist.name)"
            let description = "Konzert im \(concert.venue?.name ?? "Unknown") am \(formatDate(concert.date.shortDateOnlyString))"

            let response: CreatedPlaylist = try await spotifyRepository.createPlaylist(name: playlistName, description: description, isPublic: true)

            logSuccess("Playlist created: \(response.name)", category: .viewModel)
            
            successMessage = "Playlist created successfully!"
            createdPlaylistURL = response.url
            
            if let url = URL(string: response.url), UIApplication.shared.canOpenURL(url) {
                HapticManager.shared.navigationTap()
                await UIApplication.shared.open(url)
            }

            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
            logError("Failed to create playlist", error: error, category: .viewModel)
            handlePlaylistError(error)
        }
    }

    private func handlePlaylistError(_ error: Error) {
        if let bffError = error as? BFFError {
            switch bffError {
            case .serverError(let message):
                if message.contains("No setlist items") {
                    errorMessage = "This concert has no setlist to export"
                } else if message.contains("No Spotify tracks") {
                    errorMessage = "None of the songs have Spotify track IDs"
                } else {
                    errorMessage = "Failed to sync with Spotify"
                }
            case .invalidURL:
                print("")
            case .invalidResponse:
                print("")
            case .httpError(_):
                print("")
            case .decodingError:
                print("")
            }
        } else {
            HapticManager.shared.error()
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
