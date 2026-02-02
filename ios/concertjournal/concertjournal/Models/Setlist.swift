//
//  Setlist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation
import Supabase

public struct Setlist: Codable, Equatable {
    let id: String
    let createdAt: String
    let setlistItems: [SetlistItem]
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case setlistItems = "setlist_item_ids"
    }

    public static func == (lhs: Setlist, rhs: Setlist) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SetlistItem: Codable {
    let id: String
    let concertVisitId: String
    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistName: String
    let notes: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case artistName = "artist_name"
        case notes
        case createdAt = "created_at"
    }
}

public struct CeateSetlistItemDTO: SupabaseEncodable {
    let concertVisitId: String
    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistName: String
    let notes: String?

    init(spotifySong: SpotifySong, concertId: String, index: Int, notes: String? = nil) {
        self.concertVisitId = concertId
        self.position = index
        self.section = nil
        self.spotifyTrackId = spotifySong.id
        self.title = spotifySong.name
        self.artistName = spotifySong.artists?.first?.name ?? "UNKNOWN ARTIST"
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case concertVisitId = "concert_visit_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case artistName = "artist_name"
        case notes
    }

    func encoded() throws -> [String : AnyJSON] {
        let data: [String: AnyJSON] = [
            CodingKeys.concertVisitId.rawValue: .string(concertVisitId),
            CodingKeys.position.rawValue: .integer(position),
            CodingKeys.section.rawValue: section == nil ? .null : .string(section!),
            CodingKeys.spotifyTrackId.rawValue: spotifyTrackId == nil ? .null : .string(spotifyTrackId!),
            CodingKeys.title.rawValue: .string(title),
            CodingKeys.artistName.rawValue: .string(artistName),
            CodingKeys.notes.rawValue: notes == nil ? .null : .string(notes!)
        ]

        return data
    }
}

public struct CreateSetlistDTO: SupabaseEncodable {

    let setlistItemIds: [String]

    enum CodingKeys: String, CodingKey {
        case setlistItems = "setlist_item_ids"
    }

    func encoded() throws -> [String : AnyJSON] {
        [CodingKeys.setlistItems.rawValue: .array(setlistItemIds.map { .string($0) })]
    }
}
