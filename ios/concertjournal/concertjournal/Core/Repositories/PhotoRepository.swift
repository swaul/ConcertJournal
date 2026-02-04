//
//  PhotoRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Supabase
import UIKit

protocol PhotoRepositoryProtocol {
    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto]
    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto
    func deletePhoto(id: String, storagePath: String) async throws
}

class BFFPhotoRepository: PhotoRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }
    
    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto] {
        try await client.get("/photos/\(concertVisitId)")
    }
    
    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto {
        // 1. Get upload URL from BFF
        struct UploadURLRequest: Codable {
            let fileName: String
        }
        
        struct UploadURLResponse: Codable {
            let uploadUrl: String
            let path: String
        }
        
        let uploadURLResponse: UploadURLResponse = try await client.post(
            "/photos/upload-url",
            body: UploadURLRequest(fileName: "\(UUID().uuidString).jpg")
        )
        
        // 2. Upload image to Supabase Storage directly
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.compressionFailed
        }
        
        var request = URLRequest(url: URL(string: uploadURLResponse.uploadUrl)!)
        request.httpMethod = "PUT"
        request.httpBody = imageData
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        let (_, uploadResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = uploadResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PhotoError.uploadFailed
        }
        
        // 3. Save metadata via BFF
        struct SavePhotoRequest: Codable {
            let concert_visit_id: String
            let storage_path: String
        }
        
        let photo: ConcertPhoto = try await client.post(
            "/photos",
            body: SavePhotoRequest(
                concert_visit_id: concertVisitId,
                storage_path: uploadURLResponse.path
            )
        )
        
        return photo
    }
    
    func deletePhoto(id: String, storagePath: String) async throws {
        try await client.delete("/photos/\(id)")
    }
}

enum PhotoError: Error {
    case compressionFailed
    case uploadFailed
}
