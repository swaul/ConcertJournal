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

    var errorMessage: String? = nil
    var concerts: [FullConcertVisit] = []
    var searchText: String = ""

    var concertsToDisaplay: [FullConcertVisit] {
        if searchText.isEmpty {
            return concerts
        } else {
            return concerts.filter { $0.containsText(query: searchText) }
        }
    }

    init(concertRepository: ConcertRepositoryProtocol) {
        self.concertRepository = concertRepository
    }

    func loadConcerts() async throws {
        self.concerts = try await concertRepository.fetchConcerts(reload: false)
    }
}

extension FullConcertVisit {
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
