//
//  MockStorageService.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import UIKit
import Foundation
import Supabase

class MockStorageService: StorageServiceProtocol {

    var shouldFail = false
    var uploadedImages: [(image: UIImage, bucket: String, path: String)] = []

    func uploadImage(_ image: UIImage, to bucket: String, path: String) async throws -> URL {
        if shouldFail {
            throw StorageError.uploadFailed
        }

        uploadedImages.append((image, bucket, path))
        return URL(string: "https://example.com/\(path)")!
    }

    func deleteImage(from bucket: String, path: String) async throws {
        uploadedImages.removeAll { $0.path == path }
    }

    func getPublicURL(bucket: String, path: String) throws -> URL {
        return URL(string: "https://example.com/\(path)")!
    }
}
