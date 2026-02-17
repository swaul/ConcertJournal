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
import CoreData

@Observable
class ConcertDetailViewModel {
    
    var concert: Concert
    var errorMessage: String?
    var successMessage: String? = nil
    var createdPlaylistURL: String? = nil
    
    var isLoading: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let repository: OfflineConcertRepositoryProtocol

    init(concert: Concert, repository: OfflineConcertRepositoryProtocol) {
        self.concert = concert
        self.repository = repository
    }

    func createCalendarEntry(store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        
        let endDate = Calendar.current.date(byAdding: .hour, value: 3, to: concert.date)
        
        event.title = concert.title
        event.startDate = concert.date
        event.endDate = endDate
        event.notes = concert.notes
        if let venue = concert.venue {
            event.structuredLocation = EKStructuredLocation(mapItem: MKMapItem(location: CLLocation(latitude: venue.latitude, longitude: venue.longitude), address: MKAddress(fullAddress: venue.formattedAddress, shortAddress: nil)))
        } else {
            event.location = concert.venue?.formattedAddress
        }
        event.calendar = store.defaultCalendarForNewEvents
        
        return event
    }
    
    func applyUpdate(_ update: ConcertUpdate) async {
        do {
            try repository.updateConcert(concert, with: update)
            HapticManager.shared.success()
        } catch {
            logError("Update did not work")
        }
    }

    func deleteConcert() async throws {
        do {
            try repository.deleteConcert(concert)
            HapticManager.shared.success()
        } catch {
            logError("Deleting did not work")
        }
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

//
//@Observable
//class ConcertDetailViewModel_OFFLINEFIRST {
//
//    var concert: Concert  // Now Core Data object!
//    var comments: [Comment] = []
//    var isLoading = false
//    var errorMessage: String?
//
//    // Sharing
//    var sharedWith: [ConcertShare] = []
//    var canComment: Bool {
//        concert.isOwner || concert.isShared
//    }
//
//    private let repository: OfflineConcertRepositoryProtocol
//    private let sharingManager: SharingManager
//    private var cancellables = Set<AnyCancellable>()
//
//    init(
//        concert: Concert,
//        repository: OfflineConcertRepositoryProtocol,
//        sharingManager: SharingManager
//    ) {
//        self.concert = concert
//        self.repository = repository
//        self.sharingManager = sharingManager
//
//        loadComments()
//        observeChanges()
//    }
//
//    private func observeChanges() {
//        // Observe concert changes
//        NotificationCenter.default.publisher(
//            for: .NSManagedObjectContextObjectsDidChange
//        )
//        .sink { [weak self] _ in
//            // Concert updated
//            self?.objectWillChange.send()
//        }
//        .store(in: &cancellables)
//    }
//
//    func loadComments() {
//        // Fetch comments from Core Data
//        guard let commentsSet = concert.comments as? Set<Comment> else { return }
//        comments = Array(commentsSet).sorted { $0.createdAt > $1.createdAt }
//    }
//
//    // MARK: - Update (Instant!)
//
//    func updateConcert(with dto: ConcertUpdateDTO) async {
//        do {
//            try repository.updateConcert(concert, with: dto)
//            // UI updates automatically!
//            // Sync happens in background!
//        } catch {
//            errorMessage = "Update failed: \(error.localizedDescription)"
//        }
//    }
//
//    // MARK: - Sharing
//
//    func shareConcert(with userId: String) async {
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            try await sharingManager.shareConcert(concert, with: userId, canComment: true)
//        } catch {
//            errorMessage = "Share failed: \(error.localizedDescription)"
//        }
//    }
//
//    func addComment(text: String) async {
//        guard canComment else {
//            errorMessage = "No permission to comment"
//            return
//        }
//
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            try await sharingManager.addComment(to: concert, text: text)
//            loadComments()  // Refresh
//        } catch {
//            errorMessage = "Comment failed: \(error.localizedDescription)"
//        }
//    }
//}
