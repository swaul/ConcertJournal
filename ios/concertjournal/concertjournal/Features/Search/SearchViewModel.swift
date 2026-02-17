//
//  SearchViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Observation
import CoreData
import Combine

@Observable
class SearchViewModel {

    private let coreData = CoreDataStack.shared
    private var fetchedResultsController: NSFetchedResultsController<Concert>?

    var concertFilter = ConcertFilters()

    var errorMessage: String? = nil
    var concerts: [Concert] = []
    var searchText: String = ""

    private var cancellables = Set<AnyCancellable>()

    var filteredConcerts: [Concert] {
        concertFilter.apply(to: concerts)
    }

    var availableArtists: [String] {
        Array(Set(concerts.map { $0.artist.name })).sorted()
    }

    var availableCities: [String] {
        Array(Set(concerts.compactMap { $0.city })).sorted()
    }

    var concertsToDisaplay: [Concert] {
        if searchText.isEmpty {
            return filteredConcerts
        } else {
            return filteredConcerts.filter { $0.containsText(query: searchText) }
        }
    }

    init() {
        setupFetchedResultsController()
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
        let concerts = fetchedResultsController?.fetchedObjects ?? []
        self.concerts = concerts.sorted(by: { $0.date < $1.date })
    }
}

extension Concert {
    func containsText(query: String) -> Bool {
        if title?.contains(query) == true {
            return true
        } else if artist.name.contains(query) {
            return true
        } else if venue?.name.contains(query) == true {
            return true
        } else if city?.contains(query) == true {
            return true
        } else {
            return false
        }
    }
}
