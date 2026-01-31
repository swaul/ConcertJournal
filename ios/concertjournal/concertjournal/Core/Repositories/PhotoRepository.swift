//
//  PhotoRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Supabase

protocol PhotoRepositoryProtocol {
    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto
    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto]
    func deletePhoto(id: String, storagePath: String) async throws
}

class PhotoRepository: PhotoRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager
    private let storageService: StorageServiceProtocol

    private let bucketName = "concert-photos"

    init(supabaseClient: SupabaseClientManager, storageService: StorageServiceProtocol) {
        self.supabaseClient = supabaseClient
        self.storageService = storageService
    }

    // ✅ Upload Photo - nutzt Storage Service
    func uploadPhoto(image: UIImage, concertVisitId: String, userId: String) async throws -> ConcertPhoto {

        // 1. Generate unique path
        let fileName = UUID().uuidString + ".jpg"
        let path = "\(concertVisitId)/\(fileName)"

        // 2. Upload zu Storage (delegiert an StorageService)
        let publicURL = try await storageService.uploadImage(
            image,
            to: bucketName,
            path: path
        )

        // 3. Speichere Photo-Metadaten in DB
        let payload: [String: AnyJSON] = [
            "concert_visit_id": .string(concertVisitId),
            "user_id": .string(userId),
            "storage_path": .string(path),
            "public_url": .string(publicURL.absoluteString)
        ]

        let response = try await supabaseClient.client
            .from("concert_photos")
            .insert(payload)
            .select()
            .single()
            .execute()

        return try JSONDecoder().decode(ConcertPhoto.self, from: response.data)
    }

    // ✅ Fetch Photos für ein Concert
    func fetchPhotos(for concertVisitId: String) async throws -> [ConcertPhoto] {
        return try await supabaseClient.client
            .from("concert_photos")
            .select()
            .eq("concert_visit_id", value: concertVisitId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // ✅ Delete Photo - löscht aus Storage UND DB
    func deletePhoto(id: String, storagePath: String) async throws {
        // 1. Lösche aus Storage
        try await storageService.deleteImage(from: bucketName, path: storagePath)

        // 2. Lösche aus DB
        try await supabaseClient.client
            .from("concert_photos")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
