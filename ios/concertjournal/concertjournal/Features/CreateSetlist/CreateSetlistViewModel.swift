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

    private let didSaveSetlistSubject = PassthroughSubject<Setlist, Never>()

    public var didSaveSetlistPublisher: AnyPublisher<Setlist, Never> {
        didSaveSetlistSubject.eraseToAnyPublisher()
    }

    static func == (lhs: CreateSetlistViewModel, rhs: CreateSetlistViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    let concertId: String
    var songLoadingState: CreateSetlistStatw = .idle
    var selectedSongs = [SpotifySong]()

    private let spotifyRepository: SpotifyRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol

    init(artist: Artist? = nil, concertId: String, spotifyRepository: SpotifyRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol) {
        self.id = UUID()
        self.concertId = concertId
        self.spotifyRepository = spotifyRepository
        self.setlistRepository = setlistRepository
        guard let artist else { return }
        searchSongs(with: artist.name)
    }

    func saveSetlist() async {
        let setlistItems = selectedSongs.enumerated().map { CeateSetlistItemDTO(spotifySong: $0.element, concertId: concertId, index: $0.offset) }

        var savedSetlistItems = [SetlistItem]()
        do {
            for setlistItem in setlistItems {
                try await savedSetlistItems.append(setlistRepository.getOrCreateSetlistItem(setlistItem))
            }

            let createSetlistDTO = CreateSetlistDTO(setlistItemIds: savedSetlistItems.map { $0.id })
            let setlist = try await setlistRepository.createSetlist(createSetlistDTO)

            didSaveSetlistSubject.send(setlist)
        } catch {
            print(error)
        }
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
