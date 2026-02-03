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

extension SpotifyArtist {
    static var taylorSwift: SpotifyArtist {
        SpotifyArtist(id: "06HL4z0CvFAxyc27GXpf02",
                      externalUrls: ExternalUrls(spotify: "https://open.spotify.com/artist/06HL4z0CvFAxyc27GXpf02"),
                      followers: Followers(
                        href: nil,
                        total: 100000000
                      ),
                      genres: ["Pop"],
                      href: nil,
                      images: [SpotifyImage(
                        url: "https://i.scdn.co/image/ab6761610000e5ebe2e8e7ff002a4afda1c7147e",
                        height: 640,
                        width: 640
                      )],
                      name: "Taylor Swift",
                      popularity: 1,
                      type: "artist",
                      uri: "spotify:artist:06HL4z0CvFAxyc27GXpf02"
        )
    }
}
