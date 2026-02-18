//
//  MapViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Observation
import CoreData
import Combine
import Foundation
import MapKit

@Observable
class MapViewModel {

    private let coreData = CoreDataStack.shared
    private var fetchedResultsController: NSFetchedResultsController<Concert>?

    private var cancellables = Set<AnyCancellable>()

    var concerts: [Concert] = []

    var isLoading: Bool = true
    var errorMessage: String?
    var concertLocations: [ConcertMapItem] = []

    init() {
        setupFetchedResultsController()
    }

    func refresh() {
        updateConcerts()
    }

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Filter out deleted
        request.predicate = NSPredicate(
            format: "syncStatus != %@",
            SyncStatus.deleted.rawValue
        )

        // Sort by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: coreData.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        try? fetchedResultsController?.performFetch()

        // Initial load
        updateConcerts()
    }

    private func observeCoreDataChanges() {
        // Listen to Core Data changes
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange,
            object: coreData.viewContext
        )
        .sink { [weak self] _ in
            self?.updateConcerts()
        }
        .store(in: &cancellables)
    }

    private func updateConcerts() {
        var concerts = fetchedResultsController?.fetchedObjects ?? []
        concerts.sort(by: { $0.date < $1.date })

        let locations = Self.groupConcertsByLocation(concerts)
        guard locations != self.concertLocations else { return }

        self.concerts = concerts
        concertLocations = locations
    }

    static func groupConcertsByLocation(_ concerts: [Concert]) -> [ConcertMapItem] {
        let concertsWithVenue = concerts.filter { concert in
            guard
                let venue = concert.venue,
                (venue.latitude != 0) && (venue.longitude != 0)
            else { return false }
            return true
        }
        let grouped = Dictionary(grouping: concertsWithVenue) { concert in
            let lat = concert.venue!.latitude
            let lon = concert.venue!.longitude
            return "\(lat.rounded(toPlaces: 5))-\(lon.rounded(toPlaces: 5))"
        }

        return grouped.compactMap { (_, concerts) in
            guard let venue = concerts.first?.venue else { return nil }

            let lat = venue.latitude
            let lon = venue.longitude

            guard lat != 0, lon != 0 else { return nil }

            return ConcertMapItem(
                venueName: venue.name,
                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                concerts: concerts
            )
        }
    }

}
