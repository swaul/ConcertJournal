//
//  CreateSetlistViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Combine
import Foundation

class CreateSetlistViewModel: ObservableObject {

    @Published var songLoadingState: CreateSetlistStatw = .idle

    private let spotifyRepository: SpotifyRepositoryProtocol

    init(spotifyRepository: SpotifyRepositoryProtocol) {
        self.spotifyRepository = spotifyRepository
    }

    func searchSongs(with text: String) {
        Task {
            do {
                songLoadingState = .loading
                let result = try await spotifyRepository.searchSongs(query: text)
                songLoadingState = .loaded(result)
            } catch {
                print("Could not complete search for \(text);", error)
                songLoadingState = .error(URLError(.badURL))
            }
        }
    }
}
