//
//  CreateSetlistViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Combine
import Foundation

struct SetlistSong: Identifiable {
    let id: String
    let name: String
    let artistNames: String
    let albumName: String?
    let coverImage: String?

    init(spotifySong: SpotifySong) {
        self.id = spotifySong.id
        self.name = spotifySong.name
        self.albumName = spotifySong.album?.name
        self.artistNames = spotifySong.artists?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        self.coverImage = spotifySong.albumCover?.absoluteString
    }

    init(setlistItem: TempCeateSetlistItem) {
        self.id = setlistItem.id
        self.name = setlistItem.title
        self.albumName = setlistItem.albumName
        self.artistNames = setlistItem.artistNames
        self.coverImage = setlistItem.coverImage
    }
}

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
    var selectedSongs = [SetlistSong]()

    private let spotifyRepository: SpotifyRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol

    init(artist: Artist? = nil, spotifyRepository: SpotifyRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol) {
        self.id = UUID()
        self.spotifyRepository = spotifyRepository
        self.setlistRepository = setlistRepository
        guard let artist else { return }
        searchSongs(with: artist.name)
    }

    init(currentSelection: [TempCeateSetlistItem], spotifyRepository: SpotifyRepositoryProtocol, setlistRepository: SetlistRepositoryProtocol) {
        self.id = UUID()
        self.spotifyRepository = spotifyRepository
        self.setlistRepository = setlistRepository
        self.selectedSongs = currentSelection.map { SetlistSong(setlistItem: $0) }
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
                let setlistSongs = result.map { SetlistSong(spotifySong: $0) }
                songLoadingState = .loaded(setlistSongs)
            } catch {
                print("Could not complete search for \(text);", error)
                songLoadingState = .error(URLError(.badURL))
            }
        }
    }
}
