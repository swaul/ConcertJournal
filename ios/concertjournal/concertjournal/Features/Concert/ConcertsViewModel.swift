//
//  ContentView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Combine
import SwiftUI
import Observation
internal import Auth

@Observable
class ConcertsViewModel {

    // MARK: - Published State

    var pastConcerts: [FullConcertVisit] = []
    var futureConcerts: [FullConcertVisit] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies (Dependency Injection statt Singleton!)

    private let userManager: UserSessionManagerProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let userId: String

    private var cancellabels = Set<AnyCancellable>()

    // MARK: - Initialization

    init(concertRepository: ConcertRepositoryProtocol, userManager: UserSessionManagerProtocol, userId: String) {
        self.concertRepository = concertRepository
        self.userManager = userManager
        self.userId = userId

        concertRepository.concertsDidUpdate
            .sink { [weak self] concerts in
                self?.filterConcerts(concerts)
            }
            .store(in: &cancellabels)
    }

    // MARK: - Public Methods

    func loadConcerts() async {
        isLoading = true
        errorMessage = nil

        do {
            let concerts = try await concertRepository.fetchConcerts(reload: false)
            filterConcerts(concerts)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Ein unbekannter Fehler ist aufgetreten: \(error)"
        }

        isLoading = false
    }

    func refreshConcerts() async {
        pastConcerts.removeAll()
        futureConcerts.removeAll()

        do {
            let concerts = try await concertRepository.reloadConcerts()
            filterConcerts(concerts)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            logError("Getting concerts failed", error: error, category: .repository)
        } catch {
            logError("Getting concerts failed", error: error, category: .repository)
            errorMessage = "Ein unbekannter Fehler ist aufgetreten"
        }
    }

    func deleteConcert(_ concert: FullConcertVisit) async {
        do {
            try await concertRepository.deleteConcert(id: concert.id)

            // Update local state
            pastConcerts.removeAll { $0.id == concert.id }
            futureConcerts.removeAll { $0.id == concert.id }

        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Löschen fehlgeschlagen"
        }
    }

    // MARK: - Private Helpers

    private func filterConcerts(_ concerts: [FullConcertVisit]) {
        let now = Date.now
        let futureConcerts = concerts.filter { $0.date > now }
        let pastConcerts = concerts.filter { $0.date <= now }
        
        self.futureConcerts = futureConcerts.sorted(by: { $0.date < $1.date })
        self.pastConcerts = pastConcerts
    }
}

// MARK: - Preview Helper

//extension ConcertsViewModel {
//    static func preview() -> ConcertsViewModel {
//        let mockRepo = MockConcertRepository(mockConcerts: [], concerts: [])
//
//        // Test data
//        let artist = Artist(name: "Paula Hartmann", imageUrl: "https://i.scdn.co/image/ab6761610000e5eb6db6bdfd82c3394a6af3399e", spotifyArtistId: "3Fl31gc0mEUC2H0JWL1vic")
//        let venue = Venue(id: "V1", name: "Capitol", formattedAddress: "Schwarzer Bär 1, Hannover", latitude: nil, longitude: nil, appleMapsId: nil)
//        let concert = FullConcertVisit(
//            id: "C1",
//            createdAt: .now,
//            updatedAt: .now,
//            date: .now.addingTimeInterval(-86400 * 30), // 30 Tage in der Vergangenheit
//            venue: venue,
//            city: "Hannover",
//            rating: 5,
//            title: "Amazing Show",
//            notes: "Best concert ever!",
//            artist: artist
//        )
//
//        mockRepo.mockConcerts = [concert]
//
//        return ConcertsViewModel(concertRepository: mockRepo, userId: "preview-user")
//    }
//}
