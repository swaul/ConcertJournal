//
//  ImageUploader.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import SwiftUI
import PhotosUI
import Storage
import Supabase

public class ImageUploader {
    
    public func uploadPhoto(image: UIImage,
                            concertVisitId: String) async throws {

        guard let data = image.jpegData(compressionQuality: 0.8) else { throw CancellationError() }
        let fileName = UUID().uuidString + ".jpg"
        let path = "\(concertVisitId)/\(fileName)"

        let supabase = SupabaseManager.shared.client

        try await supabase.storage
            .from("concert-photos")
            .upload(path,
                    data: data,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: false
                    )
            )

        let publicURL = try SupabaseManager.shared.client.storage
            .from("concert-photos")
            .getPublicURL(path: path)

        try await uploadPhoto(visitId: concertVisitId, path: path, url: publicURL.absoluteString)
    }
    
    func uploadPhoto(visitId: String, path: String, url: String) async throws {
        let userId = try await SupabaseManager.shared.client.auth.session.user.id
        
        let dto = ConcertPhotoInsertDTO(
            concertVisitId: visitId,
            userId: userId.uuidString,
            storagePath: path,
            publicUrl: url
        )
        try await SupabaseManager.shared.client
            .from("concert_photos")
            .insert(dto)
            .execute()
    }
    
}

struct ConcertPhotoInsertDTO: Codable {
    let concertVisitId: String
    let userId: String
    let storagePath: String
    let publicUrl: String

    enum CodingKeys: String, CodingKey {
        case concertVisitId = "concert_visit_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case publicUrl = "public_url"
    }
}
