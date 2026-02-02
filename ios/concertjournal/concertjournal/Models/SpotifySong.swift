//
//  SpotifySong.swift
//  concertjournal
//
//  Created by Paul Kühnel on 26.12.25.
//

import Foundation

struct SpotifySongsSearchResponse: Codable {
    let tracks: SpotifySongsResponse?
}

// MARK: - SpotifySongsResponse
struct SpotifySongsResponse: Codable {
    let href: String?
    let limit: Int?
    let next: String?
    let offset: Int?
    let total: Int?
    let items: [SpotifySong]?
}

// MARK: - Item
struct SpotifySong: Codable, Identifiable {
    let id: String
    let album: SpotifyAlbum?
    let artists: [SpotifyArtist]?
    let availableMarkets: [String]?
    let discNumber, durationMS: Int?
    let explicit: Bool?
    let externalIDS: ExternalIDS?
    let externalUrls: ExternalUrls?
    let href: String?
    let isLocal, isPlayable: Bool?
    let name: String
    let popularity: Int?
    let trackNumber: Int?
    let type: ItemType?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case album, artists
        case availableMarkets = "available_markets"
        case discNumber = "disc_number"
        case durationMS = "duration_ms"
        case explicit
        case externalIDS = "external_ids"
        case externalUrls = "external_urls"
        case href, id
        case isLocal = "is_local"
        case isPlayable = "is_playable"
        case name, popularity
        case trackNumber = "track_number"
        case type, uri
    }
    
    var albumCover: URL? {
        URL(string: album?.images?.first?.url ?? "")
    }
}

// MARK: - Album
struct SpotifyAlbum: Codable {
    let albumType: AlbumTypeEnum?
    let artists: [SpotifyArtist]?
    let availableMarkets: [String]?
    let externalUrls: ExternalUrls?
    let href: String?
    let id: String?
    let images: [SpotifyImage]?
    let isPlayable: Bool?
    let name, releaseDate: String?
    let releaseDatePrecision: ReleaseDatePrecision?
    let totalTracks: Int?
    let type: AlbumTypeEnum?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case albumType = "album_type"
        case artists
        case availableMarkets = "available_markets"
        case externalUrls = "external_urls"
        case href, id, images
        case isPlayable = "is_playable"
        case name
        case releaseDate = "release_date"
        case releaseDatePrecision = "release_date_precision"
        case totalTracks = "total_tracks"
        case type, uri
    }
}

enum AlbumTypeEnum: String, Codable, CaseIterable {
    case album = "album"
    case single = "single"

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValue = try container.decode(String.self)

        if let albumType = AlbumTypeEnum.allCases.first(where: { albumType in
            // Combine all possible values we accept for the order status
            let possibleValues = [albumType.rawValue.lowercased()]
            return possibleValues.contains { $0 == decodedValue.lowercased() }
        }) {
            self = albumType
        } else {
            print("Uknown enum case found:", decodedValue)
            self = .single
        }
    }
}

enum ArtistType: String, Codable {
    case artist = "artist"
}

enum ReleaseDatePrecision: String, Codable {
    case day = "day"
}

// MARK: - ExternalIDS
struct ExternalIDS: Codable {
    let isrc: String?
}

enum ItemType: String, Codable {
    case track = "track"
}
