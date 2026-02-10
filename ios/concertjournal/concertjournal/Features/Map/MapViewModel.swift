//
//  MapViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Observation
import Foundation
import MapKit

@Observable
class MapViewModel {

    var isLoading: Bool = true
    var errorMessage: String?
    var concertLocations: [ConcertMapItem] = []

    private let concertRepository: ConcertRepositoryProtocol

    init(concertRepository: ConcertRepositoryProtocol) {
        self.concertRepository = concertRepository
        Task {
            do {
                isLoading = true
                let concerts = try await loadConcerts()
                concertLocations = Self.groupConcertsByLocation(concerts)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadConcerts() async throws -> [FullConcertVisit] {
        try await concertRepository.fetchConcerts(reload: false)
    }

    static func groupConcertsByLocation(_ concerts: [FullConcertVisit]) -> [ConcertMapItem] {
        let concertsWithVenue = concerts.filter { concert in
            guard
                let venue = concert.venue,
                (venue.latitude != nil) && (venue.longitude != nil)
            else { return false }
            return true
        }
        let grouped = Dictionary(grouping: concertsWithVenue) { concert in
            let lat = concert.venue!.latitude!
            let lon = concert.venue!.longitude!
            return "\(lat.rounded(toPlaces: 5))-\(lon.rounded(toPlaces: 5))"
        }

        return grouped.compactMap { (_, concerts) in
            guard
                let venue = concerts.first?.venue,
                let lat = venue.latitude,
                let lon = venue.longitude
            else { return nil }

            return ConcertMapItem(
                venueName: venue.name,
                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                concerts: concerts
            )
        }
    }

}
