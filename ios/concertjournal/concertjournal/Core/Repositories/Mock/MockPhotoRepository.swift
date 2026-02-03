//
//  MockPhotoRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Foundation
import UIKit

class MockPhotoRepository: PhotoRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = StorageError.uploadFailed
    var delay: TimeInterval = 0

    var mockPhotos: [ConcertPhoto] = []
    var uploadedPhotos: [(image: UIImage, concertId: String, userId: String)] = []

    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        uploadedPhotos.append((image, concertVisitId, userId))

        let photo = ConcertPhoto(
            concertVisitId: concertVisitId,
            userId: userId,
            storagePath: "mock/path/\(UUID().uuidString).jpg",
            publicUrl: "https://mock.example.com/photo.jpg",
        )

        mockPhotos.append(photo)
        return photo
    }

    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockPhotos.filter { $0.concertVisitId == concertVisitId }
    }

    func deletePhoto(id: String, storagePath: String) async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        mockPhotos.removeAll { $0.id == id }
    }
}

