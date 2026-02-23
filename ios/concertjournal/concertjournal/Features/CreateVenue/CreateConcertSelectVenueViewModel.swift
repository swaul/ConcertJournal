//
//  CreateConcertSelectVenueViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.01.26.
//

import Foundation
import MapKit
import Combine
import Supabase

@MainActor
@Observable
final class VenueSearchViewModel {

    var errorMessage: String? = nil
    var currentVenues: [VenueDTO] = []
    private let querySubjet = PassthroughSubject<String, Never>()
    var queryPublisher: AnyPublisher<String, Never> {
        return querySubjet.eraseToAnyPublisher()
    }
    var didSearch: Bool = false

    var query: String = "" {
        didSet {
            querySubjet.send(query)
        }
    }
    var results: [MKMapItem] = []
    var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    private let offlineConcertRepository: OfflineConcertRepositoryProtocol

    init(offlineConcertRepository: OfflineConcertRepositoryProtocol) {
        self.offlineConcertRepository = offlineConcertRepository

        fillWithCurrentVenues()

        queryPublisher
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard value.count >= 2 else {
                    self?.results = []
                    return
                }
                self?.search(query: value)
            }
            .store(in: &cancellables)
    }

    func fillWithCurrentVenues() {
        let venues = offlineConcertRepository.fetchConcerts().compactMap { $0.venue?.toDTO() }
        currentVenues = Array(Set(venues)).sorted(by: { $0.name < $1.name })
        isLoading = false
    }

    func search(query: String) {
        Task {
            do {
                isLoading = true

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = .pointOfInterest

                async let searchTask = MKLocalSearch(request: request).start()
                async let minLoadTimeTask: Void = Task.sleep(for: .seconds(1))

                let (response, _) = try await (searchTask, minLoadTimeTask)

                results = response.mapItems
                didSearch = true
                isLoading = false
            } catch {
                logError("Searching Venue failed", error: error)
                try? await Task.sleep(for: .seconds(1))
                isLoading = false
            }
        }
    }

    func parseVenue(venue: MKMapItem) async throws -> VenueDTO {
        guard let name = venue.name else { throw CancellationError() }

        return VenueDTO(id: UUID().uuidString,
                        name: name,
                        city: venue.addressRepresentations?.cityName,
                        formattedAddress: venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? "",
                        latitude: venue.location.coordinate.latitude,
                        longitude: venue.location.coordinate.longitude,
                        appleMapsId: venue.identifier?.rawValue)

    }
}
