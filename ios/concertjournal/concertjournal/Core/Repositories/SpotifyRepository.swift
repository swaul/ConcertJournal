//
//  SpotifyRepository.swift
//  concertjournal
//
//  Direct Spotify API Integration (no BFF)
//

import Foundation
import Supabase

// MARK: - Protocol

protocol SpotifyRepositoryProtocol {
    // Search
    func searchTracks(query: String, limit: Int, offset: Int) async throws -> [SpotifySong]
    func searchArtists(query: String, limit: Int, offset: Int) async throws -> [SpotifyArtist]
    func searchPlaylists(query: String, limit: Int) async throws -> [SpotifyPlaylist]

    // Artist
    func getArtistTopTracks(artistId: String) async throws -> [SpotifySong]

    // Tracks
    func getTracks(trackIds: [String]) async throws -> [SpotifySong]

    // Playlists
    func getUserPlaylists(limit: Int) async throws -> [SpotifyPlaylist]
    func getPlaylist(playlistId: String) async throws -> SpotifyPlaylistDetail
    func createPlaylist(name: String, description: String?, isPublic: Bool) async throws -> CreatedPlaylist
    func addTracksToPlaylist(playlistId: String, trackUris: [String]) async throws
    func importPlaylistToSetlist(playlistId: String) async throws -> [TempCeateSetlistItem]
}

// MARK: - Errors

enum SpotifyError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case authenticationRequired
    case rateLimitExceeded
    case notFound
    case noProviderToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Spotify API URL"
        case .invalidResponse:
            return "Invalid response from Spotify"
        case .httpError(let code, let message):
            return "Spotify API error (\(code)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode Spotify response: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Spotify authentication required"
        case .rateLimitExceeded:
            return "Spotify API rate limit exceeded"
        case .notFound:
            return "Resource not found on Spotify"
        case .noProviderToken:
            return "Provider token missing"
        }
    }
}

// MARK: - Models

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let tracks: Tracks
    let images: [SpotifyImage]?
    let `public`: Bool?

    struct Tracks: Codable {
        let total: Int
    }
}

struct SpotifyPlaylistDetail: Codable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]?
    let tracks: TracksPage
}

struct TracksPage: Codable {
    let items: [PlaylistTrackItem]
    let total: Int
}

struct PlaylistTrackItem: Codable {
    let track: Track?
}

struct Track: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let durationMs: Int
    let album: SpotifyAlbum?
    let uri: String

    struct ArtistDTO: Codable {
        let id: String
        let name: String
    }

    struct Album: Codable {
        let id: String
        let name: String
        let images: [SpotifyImage]?
    }

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
    }
}

struct CreatePlaylistRequest: Codable {
    let concertId: String
    let playlistName: String
    let playlistDescription: String?
    let isPublic: Bool?
}

struct CreatedPlaylist: Codable {
    let id: String
    let name: String
    let externalUrls: ExternalUrls

    var url: String {
        externalUrls.spotify
    }

    struct ExternalUrls: Codable {
        let spotify: String
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case externalUrls = "external_urls"
    }
}

// MARK: - Repository Implementation

class SpotifyRepository: SpotifyRepositoryProtocol {

    // MARK: - Properties

    private let userSessionManager: UserSessionManagerProtocol
    private let baseURL = "https://api.spotify.com/v1"
    private let session: URLSession

    // MARK: - Initialization

    init(userSessionManager: UserSessionManagerProtocol) {
        self.userSessionManager = userSessionManager

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Search Functions

    func searchTracks(query: String, limit: Int = 20, offset: Int = 0) async throws -> [SpotifySong] {
        logDebug("Searching tracks: \(query)", category: .repository)

        struct SearchResponse: Codable {
            let tracks: TracksPage

            struct TracksPage: Codable {
                let items: [SpotifySong]
            }
        }

        let params = [
            "q": query,
            "type": "track",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let response: SearchResponse = try await request(
            endpoint: "/search",
            queryParams: params
        )

        logSuccess("Found \(response.tracks.items.count) tracks", category: .repository)
        return response.tracks.items
    }

    func searchArtists(query: String, limit: Int = 20, offset: Int = 0) async throws -> [SpotifyArtist] {
        logDebug("Searching artists: \(query)", category: .repository)

        struct SearchResponse: Codable {
            let artists: ArtistsPage

            struct ArtistsPage: Codable {
                let items: [SpotifyArtist]
            }
        }

        let params = [
            "q": query,
            "type": "artist",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let response: SearchResponse = try await request(
            endpoint: "/search",
            queryParams: params
        )

        logSuccess("Found \(response.artists.items.count) artists", category: .repository)
        return response.artists.items
    }

    func searchPlaylists(query: String, limit: Int = 20) async throws -> [SpotifyPlaylist] {
        logDebug("Searching playlists: \(query)", category: .repository)

        struct SearchResponse: Codable {
            let playlists: PlaylistsPage

            struct PlaylistsPage: Codable {
                let items: [SpotifyPlaylist]

                init(from decoder: any Decoder) throws {
                    let container: KeyedDecodingContainer<SearchResponse.PlaylistsPage.CodingKeys> = try decoder.container(keyedBy: SearchResponse.PlaylistsPage.CodingKeys.self)
                    self.items = try container.decode([SpotifyPlaylist?].self, forKey: SearchResponse.PlaylistsPage.CodingKeys.items).compactMap { $0 }
                }
            }
        }

        let params = [
            "q": query,
            "type": "playlist",
            "limit": "\(limit)"
        ]

        let response: SearchResponse = try await request(
            endpoint: "/search",
            queryParams: params
        )

        logSuccess("Found \(response.playlists.items.count) playlists", category: .repository)
        return response.playlists.items
    }

    // MARK: - Artist Functions

    func getArtistTopTracks(artistId: String) async throws -> [SpotifySong] {
        logDebug("Getting top tracks for artist: \(artistId)", category: .repository)

        struct TopTracksResponse: Codable {
            let tracks: [SpotifySong]
        }

        let response: TopTracksResponse = try await request(
            endpoint: "/artists/\(artistId)/top-tracks",
            queryParams: ["market": "US"]
        )

        logSuccess("Got \(response.tracks.count) top tracks", category: .repository)
        return response.tracks
    }

    // MARK: - Track Functions

    func getTracks(trackIds: [String]) async throws -> [SpotifySong] {
        guard !trackIds.isEmpty else { return [] }

        logDebug("Getting \(trackIds.count) tracks", category: .repository)

        struct TracksResponse: Codable {
            let tracks: [SpotifySong]
        }

        let ids = trackIds.joined(separator: ",")
        let response: TracksResponse = try await request(
            endpoint: "/tracks",
            queryParams: ["ids": ids]
        )

        logSuccess("Got \(response.tracks.count) tracks", category: .repository)
        return response.tracks
    }

    // MARK: - Playlist Functions

    func getUserPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist] {
        logDebug("Getting user playlists (limit: \(limit))", category: .repository)

        struct PlaylistsResponse: Codable {
            let items: [SpotifyPlaylist]
            let total: Int
        }

        let response: PlaylistsResponse = try await requestWithProvider(
            endpoint: "/me/playlists",
            queryParams: ["limit": "\(limit)"]
        )

        logSuccess("Got \(response.total) playlists", category: .repository)
        return response.items
    }

    func getPlaylist(playlistId: String) async throws -> SpotifyPlaylistDetail {
        logDebug("Getting playlist: \(playlistId)", category: .repository)

        let playlist: SpotifyPlaylistDetail = try await requestWithProvider(
            endpoint: "/playlists/\(playlistId)"
        )

        logSuccess("Got playlist: \(playlist.name) with \(playlist.tracks.total) tracks", category: .repository)
        return playlist
    }

    func createPlaylist(
        name: String,
        description: String? = nil,
        isPublic: Bool = false
    ) async throws -> CreatedPlaylist {
        logDebug("Creating playlist: \(name)", category: .repository)

        guard let userId = userSessionManager.userId else {
            throw SpotifyError.authenticationRequired
        }

        struct CreatePlaylistBody: Codable {
            let name: String
            let description: String?
            let `public`: Bool
        }

        let body = CreatePlaylistBody(
            name: name,
            description: description,
            public: isPublic
        )

        let playlist: CreatedPlaylist = try await requestWithProvider(
            endpoint: "/users/\(userId)/playlists",
            method: .post,
            body: body
        )

        logSuccess("Playlist created: \(playlist.name)", category: .repository)
        return playlist
    }

    func addTracksToPlaylist(playlistId: String, trackUris: [String]) async throws {
        logDebug("Adding \(trackUris.count) tracks to playlist \(playlistId)", category: .repository)

        struct AddTracksBody: Codable {
            let uris: [String]
        }

        let body = AddTracksBody(uris: trackUris)

        struct AddTracksResponse: Codable {
            let snapshotId: String

            enum CodingKeys: String, CodingKey {
                case snapshotId = "snapshot_id"
            }
        }

        let _: AddTracksResponse = try await requestWithProvider(
            endpoint: "/playlists/\(playlistId)/tracks",
            method: .post,
            body: body
        )

        logSuccess("Added \(trackUris.count) tracks to playlist", category: .repository)
    }

    // MARK: - Private Helper Methods

    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        queryParams: [String: String] = [:],
        body: Encodable? = nil,
    ) async throws -> T {
        // Build URL with query parameters
        var urlString = baseURL + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams
                .map { key, value in
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(key)=\(encodedValue)"
                }
                .joined(separator: "&")
            urlString += "?" + queryString
        }

        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }

        // Get valid token
        let token = try await userSessionManager.spotifyAccessToken()

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = try? JSONDecoder().decode(SpotifyErrorResponse.self, from: data).error.message

            switch httpResponse.statusCode {
            case 401:
                throw SpotifyError.authenticationRequired
            case 404:
                throw SpotifyError.notFound
            case 429:
                throw SpotifyError.rateLimitExceeded
            default:
                throw SpotifyError.httpError(httpResponse.statusCode, errorMessage)
            }
        }

        // Decode response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logError("Failed to decode Spotify response", error: error, category: .repository)
            throw SpotifyError.decodingError(error)
        }
    }

    private func requestWithProvider<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        queryParams: [String: String] = [:],
        body: Encodable? = nil
    ) async throws -> T {
        // Build URL with query parameters
        var urlString = baseURL + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams
                .map { key, value in
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(key)=\(encodedValue)"
                }
                .joined(separator: "&")
            urlString += "?" + queryString
        }

        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }

        // Get valid token
        let token = try await userSessionManager.ensureValidProviderToken()

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = try? JSONDecoder().decode(SpotifyErrorResponse.self, from: data).error.message

            switch httpResponse.statusCode {
            case 401:
                throw SpotifyError.authenticationRequired
            case 404:
                throw SpotifyError.notFound
            case 429:
                throw SpotifyError.rateLimitExceeded
            default:
                throw SpotifyError.httpError(httpResponse.statusCode, errorMessage)
            }
        }

        // Decode response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logError("Failed to decode Spotify response", error: error, category: .repository)
            throw SpotifyError.decodingError(error)
        }
    }
}

// MARK: - Supporting Models

private struct SpotifyErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let status: Int
        let message: String
    }
}
