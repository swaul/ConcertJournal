//
//  Setlist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation
import Supabase

public struct SetlistItem: Codable {
    let id: String
    let concertVisitId: String
    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistNames: String
    let albumName: String?
    let coverImage: String?
    let notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case albumName = "album_name"
        case artistNames = "artist_names"
        case coverImage = "cover_image"
        case notes
        case createdAt = "created_at"
    }
}

public struct TempCeateSetlistItem: Equatable, Identifiable {

    public var id: String {
        title + (spotifyTrackId ?? "")
    }

    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistNames: String
    let coverImage: String?
    let albumName: String?
    let notes: String?

    init(spotifySong: SetlistSong, index: Int, notes: String? = nil) {
        self.position = index
        self.section = nil
        self.spotifyTrackId = spotifySong.id
        self.title = spotifySong.name
        self.albumName = spotifySong.albumName
        self.artistNames = spotifySong.artistNames
        self.coverImage = spotifySong.coverImage
        self.notes = notes
    }

    init(setlistItem: SetlistItem) {
        self.position = setlistItem.position
        self.section = setlistItem.section
        self.spotifyTrackId = setlistItem.spotifyTrackId
        self.title = setlistItem.title
        self.albumName = setlistItem.albumName
        self.artistNames = setlistItem.artistNames
        self.coverImage = setlistItem.coverImage
        self.notes = setlistItem.notes
    }
}

public struct CeateSetlistItemDTO: SupabaseEncodable {
    let concertVisitId: String
    let position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let albumName: String?
    let artistNames: String
    let coverImage: String?
    let notes: String?

    init(concertId: String, item: TempCeateSetlistItem) {
        self.concertVisitId = concertId
        self.position = item.position
        self.section = item.section
        self.spotifyTrackId = item.spotifyTrackId
        self.title = item.title
        self.artistNames = item.artistNames
        self.albumName = item.albumName
        self.notes = item.notes
        self.coverImage = item.coverImage
    }

    enum CodingKeys: String, CodingKey {
        case concertVisitId = "concert_visit_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case albumName = "album_name"
        case artistNames = "artist_names"
        case coverImage = "cover_image"
        case notes
    }

    func encoded() throws -> [String : AnyJSON] {
        let data: [String: AnyJSON] = [
            CodingKeys.concertVisitId.rawValue: .string(concertVisitId),
            CodingKeys.position.rawValue: .integer(position),
            CodingKeys.section.rawValue: section == nil ? .null : .string(section!),
            CodingKeys.spotifyTrackId.rawValue: spotifyTrackId == nil ? .null : .string(spotifyTrackId!),
            CodingKeys.title.rawValue: .string(title),
            CodingKeys.albumName.rawValue: albumName == nil ? .null : .string(albumName!),
            CodingKeys.artistNames.rawValue: .string(artistNames),
            CodingKeys.coverImage.rawValue: coverImage == nil ? .null : .string(coverImage!),
            CodingKeys.notes.rawValue: notes == nil ? .null : .string(notes!)
        ]

        return data
    }
}
