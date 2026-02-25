//
//  TourViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import Foundation
import Combine

@MainActor
@Observable
class ToursViewModel {
    var tours: [Tour] = []
    var upcomingTours: [Tour] = []
    var ongoingTours: [Tour] = []
    var pastTours: [Tour] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let tourRepository: OfflineTourRepositoryProtocol
    private let concertRepository: OfflineConcertRepositoryProtocol

    init(tourRepository: OfflineTourRepositoryProtocol, concertRepository: OfflineConcertRepositoryProtocol) {
        self.tourRepository = tourRepository
        self.concertRepository = concertRepository
        loadTours()
    }

    func loadTours() {
        isLoading = true
        do {
            tours = try tourRepository.getAllTours()
            upcomingTours = try tourRepository.getToursByStatus(.upcoming)
            ongoingTours = try tourRepository.getToursByStatus(.ongoing)
            pastTours = try tourRepository.getToursByStatus(.finished)
            errorMessage = nil
        } catch {
            errorMessage = "Fehler beim Laden der Touren: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func createTour(name: String, startDate: Date, endDate: Date, artist: ArtistDTO, description: String? = nil) async {
        do {
            _ = try await tourRepository.createTour(name: name, startDate: startDate, endDate: endDate, artist: artist, description: description)
            loadTours()
        } catch {
            logError("Error creating tour", error: error)
        }
    }

    func updateTour(_ tour: Tour, name: String, startDate: Date, endDate: Date, description: String? = nil) {
        tourRepository.updateTour(tour, name: name, startDate: startDate, endDate: endDate, description: description)
        loadTours()
    }

    func deleteTour(_ tour: Tour) {
        do {
            try tourRepository.deleteTour(tour)
            loadTours()
        } catch {
            errorMessage = "Fehler beim Löschen: \(error.localizedDescription)"
        }
    }

    func addConcertToTour(_ concert: Concert, tour: Tour) {
        tourRepository.addConcertToTour(concert, tour: tour)
        loadTours()
    }

    func removeConcertFromTour(_ concert: Concert) {
        tourRepository.removeConcertFromTour(concert)
        loadTours()
    }
}
