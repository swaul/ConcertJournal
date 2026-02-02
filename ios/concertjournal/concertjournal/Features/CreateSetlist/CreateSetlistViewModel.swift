//
//  CreateSetlistViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Combine
import Foundation

@Observable
class CreateSetlistViewModel: Hashable, Equatable {

    private let didSaveSetlistSubject = PassthroughSubject<[TempCeateSetlistItem], Never>()

    public var didSaveSetlistPublisher: AnyPublisher<[TempCeateSetlistItem], Never> {
        didSaveSetlistSubject.eraseToAnyPublisher()
    }

    static func == (lhs: CreateSetlistViewModel, rhs: CreateSetlistViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    var songLoadingState: CreateSetlistStatw = .idle
    var selectedSongs = [SpotifySong]()

    private let spotifyRepository: SpotifyRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol

    init(artist: Artist? = nil, spotifyRepository: SpotifyRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol) {
        self.id = UUID()
        self.spotifyRepository = spotifyRepository
        self.setlistRepository = setlistRepository
        guard let artist else { return }
        searchSongs(with: artist.name)
    }

    func saveSetlist() {
        let setlistItems = selectedSongs.enumerated().map { TempCeateSetlistItem(spotifySong: $0.element, index: $0.offset) }

        didSaveSetlistSubject.send(setlistItems)
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
