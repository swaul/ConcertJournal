//
//  SearchViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Observation

@Observable
class SearchViewModel {

    private let concertRepository: ConcertRepositoryProtocol

    var concertFilter = ConcertFilters()

    var errorMessage: String? = nil
    var concerts: [PartialConcertVisit] = []
    var searchText: String = ""

    var filteredConcerts: [PartialConcertVisit] {
        concertFilter.apply(to: concerts)
    }

    var availableArtists: [String] {
        Array(Set(concerts.map { $0.artist.name })).sorted()
    }

    var availableCities: [String] {
        Array(Set(concerts.compactMap { $0.city })).sorted()
    }

    var concertsToDisaplay: [PartialConcertVisit] {
        if searchText.isEmpty {
            return filteredConcerts
        } else {
            return filteredConcerts.filter { $0.containsText(query: searchText) }
        }
    }

    init(concertRepository: ConcertRepositoryProtocol) {
        self.concertRepository = concertRepository
    }

    func loadConcerts() async throws {
        self.concerts = try await concertRepository.fetchConcerts(reload: false)
    }
}

extension PartialConcertVisit {
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
