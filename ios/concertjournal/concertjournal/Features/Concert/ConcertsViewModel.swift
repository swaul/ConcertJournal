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

    var concertToday: PartialConcertVisit? = nil
    var pastConcerts: [PartialConcertVisit] = []
    var futureConcerts: [PartialConcertVisit] = []
    var isLoading: Bool = true
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

        Task {
            await loadConcerts()
        }
    }

    // MARK: - Public Methods

    func loadConcerts() async {
        isLoading = true
        errorMessage = nil

        do {
            let concerts = try await concertRepository.fetchConcerts(reload: false)
            filterConcerts(concerts)
        } catch let error as NetworkError {
            HapticManager.shared.error()
            errorMessage = error.localizedDescription
        } catch {
            HapticManager.shared.error()
            errorMessage = "Ein unbekannter Fehler ist aufgetreten: \(error)"
        }

        isLoading = false
    }

    func refreshConcerts() async {
        withAnimation {
            pastConcerts.removeAll()
            futureConcerts.removeAll()
            errorMessage = nil
        }

        do {
            let concerts = try await concertRepository.fetchConcerts(reload: true)
            filterConcerts(concerts)
        } catch let error as NetworkError {
            HapticManager.shared.error()
            errorMessage = error.localizedDescription
            logError("Getting concerts failed", error: error, category: .repository)
        } catch {
            HapticManager.shared.error()
            logError("Getting concerts failed", error: error, category: .repository)
            errorMessage = "Ein unbekannter Fehler ist aufgetreten"
        }
    }

    func deleteConcert(_ concert: PartialConcertVisit) async {
        errorMessage = nil

        do {
            try await concertRepository.deleteConcert(id: concert.id)

            // Update local state
            withAnimation {
                pastConcerts.removeAll { $0.id == concert.id }
                futureConcerts.removeAll { $0.id == concert.id }
            }
        } catch let error as NetworkError {
            HapticManager.shared.error()
            errorMessage = error.localizedDescription
        } catch {
            HapticManager.shared.error()
            errorMessage = "Löschen fehlgeschlagen"
        }
    }

    // MARK: - Private Helpers

    private func filterConcerts(_ concerts: [PartialConcertVisit]) {
        let now = Date.now

        let calendar = Calendar.current
        concertToday = concerts.first(where: { calendar.isDateInToday($0.date) })
        let concertsWithoutToday = concerts.filter { $0.id != (concertToday?.id ?? "") }

        let futureConcerts = concertsWithoutToday.filter { $0.date > now }
        let pastConcerts = concertsWithoutToday.filter { $0.date <= now }

        HapticManager.shared.success()
        withAnimation {
            self.futureConcerts = futureConcerts.sorted(by: { $0.date < $1.date })
            self.pastConcerts = pastConcerts
        }
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
