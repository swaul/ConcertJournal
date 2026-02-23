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

    var isSearching: Bool = true
    var artistsResponse: [SpotifyArtist] = []
    var currentArtists: [Artist] = []

    var errorMessage: String? = nil

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
        isSearching = false
    }

    func searchArtists(with text: String) {
        Task {
            do {
                isSearching = true
                async let resultTask = spotifyRepository.searchArtists(query: text, limit: 10, offset: 0)
                async let minLoadTimeTask: Void = Task.sleep(for: .seconds(1))

                let (result, _) = try await (resultTask, minLoadTimeTask)
                artistsResponse = result
                isSearching = false
            } catch {
                try? await Task.sleep(for: .seconds(1))
                isSearching = false
                logError("Searching artist failed", error: error, category: .network)
                errorMessage = "Suche fehlgeschlagen. Bitte versuche es später nochmal."
            }
        }
    }

}
