import SwiftUI
import PhotosUI

class ImageUploader {
    
    func uploadPhoto(
        data: Data,
        concertVisitId: String
    ) async throws -> (path: String, url: String) {

        let fileName = UUID().uuidString + ".jpg"
        let path = "\(concertVisitId)/\(fileName)"

        let supabase = SupabaseManager.shared.client

        try await supabase.storage
            .from("concert-photos")
            .upload(
                path,
                file: data,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let publicURL = supabase.storage
            .from("concert-photos")
            .getPublicURL(path: path)

        return (path, publicURL.absoluteString)
    }
    
//    func uploadPhoto() {
//        let dto = ConcertPhotoInsertDTO(
//            concertVisitId: visitId,
//            storagePath: path,
//            publicUrl: url
//        )
//
//        try await supabase
//            .from("concert_photos")
//            .insert(dto)
//            .execute()
//    }
    
    func loadImageData(from item: PhotosPickerItem) async throws -> Data {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8)
        else {
            throw NSError()
        }

        return jpeg
    }
    
}

struct ConcertPhotoInsertDTO: Codable {
    let concertVisitId: String
    let storagePath: String
    let publicUrl: String

    enum CodingKeys: String, CodingKey {
        case concertVisitId = "concert_visit_id"
        case storagePath = "storage_path"
        case publicUrl = "public_url"
    }
}
