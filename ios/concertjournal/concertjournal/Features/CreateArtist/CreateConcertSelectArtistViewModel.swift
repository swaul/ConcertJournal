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

    private let spotifyRepository: SpotifyRepositoryProtocol

    init(spotifyRepository: SpotifyRepositoryProtocol) {
        self.spotifyRepository = spotifyRepository
    }


    func searchArtists(with text: String) {
        Task {
            let result = try await spotifyRepository.searchArtist(query: text)
            artistsResponse = result
        }
    }

}
