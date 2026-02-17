//
//  Setlist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation
import Supabase

public struct SetlistItemDTO: Codable {

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
    let createdAt: String

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
    
    internal init(id: String, concertVisitId: String, position: Int, section: String? = nil, spotifyTrackId: String? = nil, title: String, artistNames: String, albumName: String? = nil, coverImage: String? = nil, notes: String? = nil, createdAt: Date) {
        self.id = id
        self.concertVisitId = concertVisitId
        self.position = position
        self.section = section
        self.spotifyTrackId = spotifyTrackId
        self.title = title
        self.artistNames = artistNames
        self.albumName = albumName
        self.coverImage = coverImage
        self.notes = notes
        self.createdAt = createdAt.supabseDateString
    }
}

public struct TempCeateSetlistItem: Equatable, Identifiable, Codable {

    public var id: String {
        title + (spotifyTrackId ?? "") + String(position) + artistNames
    }

    let existingItemid: String?
    var position: Int
    let section: String?
    let spotifyTrackId: String?
    let title: String
    let artistNames: String
    let coverImage: String?
    let albumName: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case existingItemid = "existing_item_id"
        case position
        case section
        case spotifyTrackId = "spotify_track_id"
        case title
        case artistNames = "artist_names"
        case coverImage = "cover_image"
        case albumName = "album_name"
        case notes
    }

    init(spotifySong: SetlistSong, index: Int, notes: String? = nil) {
        self.position = index
        self.section = nil
        self.spotifyTrackId = spotifySong.id
        self.title = spotifySong.name
        self.albumName = spotifySong.albumName
        self.artistNames = spotifySong.artistNames
        self.coverImage = spotifySong.coverImage
        self.notes = notes
        self.existingItemid = nil
    }

    init(setlistItem: SetlistItem) {
        self.existingItemid = setlistItem.id.uuidString
        self.position = Int(setlistItem.position)
        self.section = setlistItem.section
        self.spotifyTrackId = setlistItem.spotifyTrackId
        self.title = setlistItem.title
        self.albumName = setlistItem.albumName
        self.artistNames = setlistItem.artistNames
        self.coverImage = setlistItem.coverImage
        self.notes = setlistItem.notes
    }

    init(_ item: Track, index: Int) {
        self.existingItemid = nil
        self.section = nil
        self.spotifyTrackId = item.id
        self.title = item.name
        self.albumName = item.album?.name
        self.artistNames = item.artists.map { $0.name }.joined(separator: ", ")
        self.coverImage = item.album?.images?.first?.url
        self.notes = nil
        self.position = index
    }
}

public struct CreateSetlistItemDTO: Encodable {
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
    
    init(from item: UpdateSetlistItemDTO) {
        self.concertVisitId = item.concertVisitId
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
}

public struct UpdateSetlistItemDTO: Encodable {
    let id: String?
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
        self.id = item.existingItemid
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
    
    var createSetlistItem: CreateSetlistItemDTO {
        CreateSetlistItemDTO(from: self)
    }
}
