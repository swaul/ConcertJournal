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
    
    private let venueRepository: VenueRepositoryProtocol
    
    init(venueRepository: VenueRepositoryProtocol) {
        self.venueRepository = venueRepository
        
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
    
    func saveVenue(venue: MKMapItem) async throws -> VenueDTO {
        guard let name = venue.name else { throw CancellationError() }
        
        let venue = CreateVenueDTO(name: name,
                                   city: venue.addressRepresentations?.cityName,
                                   formattedAddress: venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? "",
                                   latitude: venue.location.coordinate.latitude,
                                   longitude: venue.location.coordinate.longitude,
                                   appleMapsId: venue.identifier?.rawValue)
        
        let venueId = try await venueRepository.createVenue(venue)
        
        return VenueDTO(id: venueId,
                     name: name,
                     city: venue.city,
                     formattedAddress: venue.formattedAddress,
                     latitude: venue.latitude,
                     longitude: venue.longitude,
                     appleMapsId: venue.appleMapsId)
    }
}
