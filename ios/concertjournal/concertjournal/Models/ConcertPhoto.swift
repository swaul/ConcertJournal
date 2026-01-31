//
//  ConcertPhoto.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//


struct ConcertPhoto: Codable, Identifiable {
    var id: String {
        publicUrl
    }

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
