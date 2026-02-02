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
    private let concertRepository: ConcertRepositoryProtocol

    init(spotifyRepository: SpotifyRepositoryProtocol, concertRepository: ConcertRepositoryProtocol) {
        self.spotifyRepository = spotifyRepository
        self.concertRepository = concertRepository

        fillWithCurrentArtists()
    }

    func fillWithCurrentArtists() {
        let artists = concertRepository.concerts.map { $0.artist }
        currentArtists = Array(Set(artists)).sorted(by: { $0.name < $1.name })
    }

    func searchArtists(with text: String) {
        Task {
            let result = try await spotifyRepository.searchArtist(query: text)
            artistsResponse = result
        }
    }

}
