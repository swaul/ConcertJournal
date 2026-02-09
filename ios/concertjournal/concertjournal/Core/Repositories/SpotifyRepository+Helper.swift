//
//  SpotifyHelpers.swift
//  concertjournal
//
//  Helper functions for Spotify integration
//

import Foundation

// MARK: - Spotify URI Helpers

extension String {
    /// Converts a Spotify ID to a Spotify URI
    /// - Parameter type: The type of Spotify resource (track, artist, album, playlist)
    /// - Returns: Spotify URI string (e.g., "spotify:track:abc123")
    func toSpotifyURI(type: SpotifyURIType) -> String {
        return "spotify:\(type.rawValue):\(self)"
    }

    /// Extracts the Spotify ID from a Spotify URI
    /// - Returns: The ID portion of the URI, or the original string if not a valid URI
    func spotifyIDFromURI() -> String {
        let components = self.components(separatedBy: ":")
        return components.last ?? self
    }

    /// Checks if this string is a valid Spotify URI
    var isSpotifyURI: Bool {
        return self.hasPrefix("spotify:")
    }
}

enum SpotifyURIType: String {
    case track
    case artist
    case album
    case playlist
    case user
}

// MARK: - Array Extensions for Batch Operations

extension Array where Element == String {
    /// Converts an array of Spotify IDs to Spotify URIs
    func toSpotifyURIs(type: SpotifyURIType) -> [String] {
        return self.map { $0.toSpotifyURI(type: type) }
    }

    /// Chunks the array into smaller arrays of specified size
    /// Useful for Spotify API batch operations that have size limits
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Setlist to Playlist Conversion

extension SpotifyRepository {

    /// Creates a Spotify playlist from a setlist
    /// - Parameters:
    ///   - setlistItems: Array of setlist items with Spotify track IDs
    ///   - name: Name for the playlist
    ///   - description: Optional description
    ///   - isPublic: Whether the playlist should be public
    /// - Returns: Created playlist with URL
    func createPlaylistFromSetlist(
        setlistItems: [TempCeateSetlistItem],
        name: String,
        description: String? = nil,
        isPublic: Bool = false
    ) async throws -> CreatedPlaylist {

        // Create the playlist
        let playlist = try await createPlaylist(
            name: name,
            description: description,
            isPublic: isPublic
        )

        // Get track URIs from setlist items
        let trackURIs = setlistItems
            .compactMap { $0.spotifyTrackId }
            .map { $0.toSpotifyURI(type: .track) }

        guard !trackURIs.isEmpty else {
            logWarning("No tracks to add to playlist", category: .repository)
            return playlist
        }

        // Spotify allows max 100 tracks per request
        let chunks = trackURIs.chunked(into: 100)

        // Add tracks in chunks
        for chunk in chunks {
            try await addTracksToPlaylist(playlistId: playlist.id, trackUris: chunk)
        }

        logSuccess("Added \(trackURIs.count) tracks to playlist '\(name)'", category: .repository)

        return playlist
    }

    /// Imports tracks from a Spotify playlist to create setlist items
    /// - Parameter playlistId: The Spotify playlist ID
    /// - Returns: Array of temporary setlist items
    func importPlaylistToSetlist(playlistId: String) async throws -> [TempCeateSetlistItem] {

        let playlist = try await getPlaylist(playlistId: playlistId)

        let items: [TempCeateSetlistItem] = playlist.tracks.items.compactMap { $0.track }.enumerated().map { index, track in
            return TempCeateSetlistItem(track, index: index)
        }

        logSuccess("Imported \(items.count) tracks from playlist '\(playlist.name)'", category: .repository)

        return items
    }
}

// MARK: - Error Recovery

extension SpotifyRepository {

    /// Safely executes a Spotify request with automatic token refresh on auth errors
    func executeWithRetry<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch SpotifyError.authenticationRequired {
            logInfo("Auth error, refreshing token and retrying", category: .repository)

            // Token will be refreshed automatically by ensureValidProviderToken
            // in the next request
            return try await operation()
        }
    }
}

// MARK: - Rate Limiting Helper

actor SpotifyRateLimiter {
    private var lastRequestTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.1 // 100ms between requests

    func waitIfNeeded() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)

        if timeSinceLastRequest < minimumInterval {
            let waitTime = minimumInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        lastRequestTime = Date()
    }
}
