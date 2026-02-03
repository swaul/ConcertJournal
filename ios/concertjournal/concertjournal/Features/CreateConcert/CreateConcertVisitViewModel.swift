//
//  CreateConcertVisitViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import Supabase
import Combine
import Foundation
import UIKit

@Observable
class CreateConcertVisitViewModel: Hashable, Equatable {
    static func == (lhs: CreateConcertVisitViewModel, rhs: CreateConcertVisitViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: String
    var artist: Artist?

    private let artistRepository: ArtistRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let userSessionManager: UserSessionManagerProtocol
    private let photoRepository: PhotoRepositoryProtocol

    init(artistRepository: ArtistRepositoryProtocol,
         concertRepository: ConcertRepositoryProtocol,
         userSessionManager: UserSessionManagerProtocol,
         photoRepository: PhotoRepositoryProtocol,
         setlistRepository: SetlistRepositoryProtocol) {
        self.artistRepository = artistRepository
        self.concertRepository = concertRepository
        self.photoRepository = photoRepository
        self.userSessionManager = userSessionManager
        self.setlistRepository = setlistRepository

        self.id = UUID().uuidString
    }

    #if DEBUG
    init(artist: Artist) {
        self.artist = artist

        self.artistRepository = MockArtistRepository()
        self.concertRepository = MockConcertRepository()
        self.photoRepository = MockPhotoRepository()
        self.userSessionManager = MockUserSessionManager()
        self.setlistRepository = MockSetlistRepository()

        self.id = UUID().uuidString
    }
    #endif

    func createVisit(from new: NewConcertVisit) async throws -> String {
        guard let artist else { throw URLError(.notConnectedToInternet) }
        let artistId = try await artistRepository.getOrCreateArtist(artist)

        guard let userId = userSessionManager.user?.id.uuidString else { throw URLError(.notConnectedToInternet) }
        let newConcert = NewConcertDTO(with: new, by: userId, with: artistId)

        let concert = try await concertRepository.createConcert(newConcert)

        let setlistItems = new.setlistItems.map { CeateSetlistItemDTO(concertId: concert.id, item: $0) }

        for item in setlistItems {
            let result = try await setlistRepository.createSetlistItem(item)
            print("Created setlist item", result.title)
        }

        return concert.id
    }
    
    func uploadSelectedPhotos(selectedImages: [UIImage], visitId: String) async throws {
        guard let userId = userSessionManager.user?.id.uuidString else { return}
        for image in selectedImages {
            _ = try await photoRepository.uploadPhoto(image: image, concertVisitId: visitId, userId: userId)
        }
    }
}

struct ConcertVisitIdDTO: Codable {
    let id: String
}
