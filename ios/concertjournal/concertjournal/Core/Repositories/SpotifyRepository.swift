//
//  BFFSpotifyRepository.swift
//  concertjournal
//
//  Spotify Repository mit BFF Integration
//

import Foundation

// MARK: - Protocol

protocol SpotifyRepositoryProtocol {
    // Search
    func searchTracks(query: String, limit: Int) async throws -> [SpotifySong]
    func searchArtists(query: String, limit: Int) async throws -> [SpotifyArtist]
    func getArtistTopTracks(artistId: String) async throws -> [SpotifySong]
    func getTracks(trackIds: [String]) async throws -> [SpotifySong]

    // Playlists - NEW
    func getUserPlaylists(limit: Int) async throws -> [SpotifyPlaylist]
    func getPlaylist(playlistId: String) async throws -> SpotifyPlaylistDetail
    func createPlaylistFromSetlist(concertId: String, playlistName: String, description: String?, isPublic: Bool) async throws -> CreatedPlaylist
    func importPlaylistToSetlist(concertId: String?, playlistId: String) async throws -> PlaylistImportResult
}

enum SpotifyRepositoryError: Error {
    case noProviderToken
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let tracks_total: Int
    let images: [SpotifyImage]?
}

struct SpotifyPlaylistDetail: Codable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]?
    let tracks: [PlaylistTrack]

    struct PlaylistTrack: Codable {
        let id: String
        let name: String
        let artists: String
        let duration_ms: Int
        let album: SpotifyAlbum?
    }
}

struct CreatedPlaylist: Codable {
    let id: String
    let name: String
    let url: String
}

struct PlaylistImportResult: Codable {
    let skipped: Int
    let items: [TempCeateSetlistItem]
}

// MARK: - Request Models

struct CreatePlaylistRequest: Codable {
    let concertId: String
    let playlistName: String
    let playlistDescription: String?
    let isPublic: Bool?
}

struct ImportPlaylistRequest: Codable {
    let concertId: String?
    let playlistId: String
}

// MARK: - Backend Response Wrappers

private struct PlaylistsResponse: Codable {
    let total: Int
    let playlists: [SpotifyPlaylist]
}

private struct CreatePlaylistResponse: Codable {
    let success: Bool
    let playlist: CreatedPlaylist
}

private struct ImportPlaylistResponse: Codable {
    let skipped: Int
    let items: [TempCeateSetlistItem]
}

// MARK: - BFF Repository Implementation

class BFFSpotifyRepository: SpotifyRepositoryProtocol {

    private let client: BFFClient

    init(client: BFFClient) {
        self.client = client
    }

    // MARK: - Search Functions

    func searchTracks(query: String, limit: Int = 20) async throws -> [SpotifySong] {
        logDebug("Searching tracks: \(query)", category: .repository)

        struct SearchResponse: Codable {
            let tracks: [SpotifySong]
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: [SpotifySong] = try await client.get("/spotify/search/tracks?q=\(encoded)")

        logSuccess("Found \(response.count) tracks", category: .repository)
        return response
    }

    func searchArtists(query: String, limit: Int = 20) async throws -> [SpotifyArtist] {
        logDebug("Searching artists: \(query)", category: .repository)

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: [SpotifyArtist] = try await client.get("/spotify/search/artists?q=\(encoded)")

        logSuccess("Found \(response.count) artists", category: .repository)
        return response
    }

    func getArtistTopTracks(artistId: String) async throws -> [SpotifySong] {
        logDebug("Getting top tracks for artist: \(artistId)", category: .repository)

        let response: [SpotifySong] = try await client.get("/spotify/artists/\(artistId)/top-tracks")

        logSuccess("Got \(response.count) top tracks", category: .repository)
        return response
    }

    func getTracks(trackIds: [String]) async throws -> [SpotifySong] {
        guard !trackIds.isEmpty else { return [] }

        logDebug("Getting \(trackIds.count) tracks", category: .repository)

        let ids = trackIds.joined(separator: ",")
        let response: [SpotifySong] = try await client.get("/spotify/tracks?ids=\(ids)")

        logSuccess("Got \(response.count) tracks", category: .repository)
        return response
    }

    // MARK: - ✅ Playlist Functions

    func getUserPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist] {
        logDebug("Getting user playlists (limit: \(limit))", category: .repository)

        let response: PlaylistsResponse = try await client.get("/spotify/playlists?limit=\(limit)")

        logSuccess("Got \(response.total) playlists", category: .repository)
        return response.playlists
    }

    func getPlaylist(playlistId: String) async throws -> SpotifyPlaylistDetail {
        logDebug("Getting playlist: \(playlistId)", category: .repository)

        let response: SpotifyPlaylistDetail = try await client.get("/spotify/playlists/\(playlistId)")

        logSuccess("Got playlist: \(response.name) with \(response.tracks.count) tracks", category: .repository)
        return response
    }

    func createPlaylistFromSetlist(
        concertId: String,
        playlistName: String,
        description: String? = nil,
        isPublic: Bool = false
    ) async throws -> CreatedPlaylist {
        logDebug("Creating playlist from setlist: \(concertId)", category: .repository)

        let request = CreatePlaylistRequest(
            concertId: concertId,
            playlistName: playlistName,
            playlistDescription: description,
            isPublic: isPublic
        )

        let response: CreatePlaylistResponse = try await client.post("/spotify/playlists/from-setlist",
                                                                     body: request)

        logSuccess("Playlist created: \(response.playlist.name)", category: .repository)
        return response.playlist
    }

    func importPlaylistToSetlist(
        concertId: String?,
        playlistId: String
    ) async throws -> PlaylistImportResult {
        logDebug("Importing playlist \(playlistId) to concert \(concertId)", category: .repository)

        let request = ImportPlaylistRequest(
            concertId: concertId,
            playlistId: playlistId
        )

        let response: ImportPlaylistResponse = try await client.post("/spotify/playlists/import",
                                                                     body: request)

        logSuccess("skipped \(response.skipped)", category: .repository)

        let imported = response.items.map { $0.title }.joined(separator: ", ")
        logSuccess("Got tracks: \(imported)")

        return PlaylistImportResult(
            skipped: response.skipped,
            items: response.items
        )
    }
}
