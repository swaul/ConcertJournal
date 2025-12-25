//
//  SpotifyArtist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.12.25.
//

import Foundation

struct SpotifyArtistSearchResponse: Codable {
    let artists: SpotifyArtistsResponse
}

// MARK: - Artists
struct SpotifyArtistsResponse: Codable {
    let href: String?
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
    let items: [SpotifyArtist]
}

// MARK: - Item
struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let externalUrls: ExternalUrls?
    let followers: Followers?
    let genres: [String]?
    let href: String?
    let images: [SpotifyImage]?
    let name: String
    let popularity: Int?
    let type, uri: String?

    enum CodingKeys: String, CodingKey {
        case externalUrls = "external_urls"
        case followers, genres, href, id, images, name, popularity, type, uri
    }
    
    var firstImageURL: URL? {
        URL(string: images?.first?.url ?? "")
    }
}

// MARK: - ExternalUrls
struct ExternalUrls: Codable {
    let spotify: String?
}

// MARK: - Followers
struct Followers: Codable {
    let href: String?
    let total: Int?
}

// MARK: - Image
struct SpotifyImage: Codable {
    let url: String?
    let height, width: Int?
}
