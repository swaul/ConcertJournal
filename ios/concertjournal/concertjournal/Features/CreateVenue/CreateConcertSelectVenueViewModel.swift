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

    private let querySubjet = PassthroughSubject<String, Never>()
    var queryPublisher: AnyPublisher<String, Never> {
        return querySubjet.eraseToAnyPublisher()
    }

    var query: String = "" {
        didSet {
            querySubjet.send(query)
        }
    }
    var results: [MKMapItem] = []
    var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    init() {
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

    func search(query: String) {
        isLoading = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            Task { @MainActor in
                self?.isLoading = false
                self?.results = response?.mapItems ?? []
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
