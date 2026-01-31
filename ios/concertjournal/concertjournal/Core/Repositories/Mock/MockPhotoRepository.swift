//
//  MockPhotoRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import UIKit

class MockPhotoRepository: PhotoRepositoryProtocol {

    var mockPhotos: [ConcertPhoto] = []

    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto {
        let photo = ConcertPhoto(
            concertVisitId: concertVisitId,
            userId: userId,
            storagePath: "mock/path.jpg",
            publicUrl: "https://example.com/mock.jpg",
        )
        mockPhotos.append(photo)
        return photo
    }

    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto] {
        return mockPhotos.filter { $0.concertVisitId == concertVisitId }
    }

    func deletePhoto(id: String, storagePath: String) async throws {
        mockPhotos.removeAll { $0.id == id }
    }
}
