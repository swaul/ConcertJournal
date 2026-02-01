//
//  StorageService.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Foundation
import Supabase
import UIKit

protocol StorageServiceProtocol {
    func uploadImage(_ image: UIImage, to bucket: String, path: String) async throws -> URL
    func deleteImage(from bucket: String, path: String) async throws
    func getPublicURL(bucket: String, path: String) throws -> URL
}

class StorageService: StorageServiceProtocol {

    private let supabaseClient: SupabaseClientManager

    init(supabaseClient: SupabaseClientManager) {
        self.supabaseClient = supabaseClient
    }

    func uploadImage(_ image: UIImage, to bucket: String, path: String) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.compressionFailed
        }

        try await supabaseClient.client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        return try getPublicURL(bucket: bucket, path: path)
    }

    func deleteImage(from bucket: String, path: String) async throws {
        try await supabaseClient.client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    func getPublicURL(bucket: String, path: String) throws -> URL {
        return try supabaseClient.client.storage
            .from(bucket)
            .getPublicURL(path: path)
    }
}

enum StorageError: Error, LocalizedError {
    case compressionFailed
    case uploadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Bild konnte nicht komprimiert werden"
        case .uploadFailed:
            return "Upload fehlgeschlagen"
        case .deleteFailed:
            return "Löschen fehlgeschlagen"
        }
    }
}
