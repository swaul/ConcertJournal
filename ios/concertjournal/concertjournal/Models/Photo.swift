//
//  Photo.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation

public struct Photo: Codable {
    let id: String
    let concertVisitId: String
    let storagePath: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}
