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

class CreateConcertVisitViewModel: ObservableObject, Hashable, Equatable {
    static func == (lhs: CreateConcertVisitViewModel, rhs: CreateConcertVisitViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: String
    @Published var artist: Artist?

    private let artistRepository: ArtistRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let userSessionManager: UserSessionManager
    private let photoRepository: PhotoRepositoryProtocol

    init(artistRepository: ArtistRepositoryProtocol,
         concertRepository: ConcertRepositoryProtocol,
         userSessionManager: UserSessionManager,
         photoRepository: PhotoRepositoryProtocol) {
        self.artistRepository = artistRepository
        self.concertRepository = concertRepository
        self.photoRepository = photoRepository
        self.userSessionManager = userSessionManager

        self.id = UUID().uuidString
    }

    func createVisit(from new: NewConcertVisit) async throws -> String {
        guard let artist else { throw URLError(.notConnectedToInternet) }
        let artistId = try await artistRepository.getOrCreateArtist(artist)

        guard let userId = userSessionManager.user?.id.uuidString else { throw URLError(.notConnectedToInternet) }
        let newConcert = NewConcertDTO(with: new, by: userId, with: artistId)

        return try await concertRepository.createConcert(newConcert)
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
