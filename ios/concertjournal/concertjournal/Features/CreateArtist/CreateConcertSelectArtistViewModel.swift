//
//  CreateConcertSelectArtistViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

import Combine
import SpotifyiOS
import Supabase

@Observable
class CreateConcertSelectArtistViewModel {
    
    var artistsResponse: [SpotifyArtist] = []
    var currentArtists: [Artist] = []

    private let spotifyRepository: SpotifyRepositoryProtocol
    private let offlineConcertRepository: OfflineConcertRepositoryProtocol

    init(spotifyRepository: SpotifyRepositoryProtocol, offlineConcertRepository: OfflineConcertRepositoryProtocol) {
        self.spotifyRepository = spotifyRepository
        self.offlineConcertRepository = offlineConcertRepository

        fillWithCurrentArtists()
    }

    func fillWithCurrentArtists() {
        let artists = offlineConcertRepository.fetchConcerts().map { $0.artist }
        currentArtists = Array(Set(artists)).sorted(by: { $0.name < $1.name })
    }

    func searchArtists(with text: String) {
        Task {
            let result = try await spotifyRepository.searchArtists(query: text, limit: 10, offset: 0)
            artistsResponse = result
        }
    }

}
