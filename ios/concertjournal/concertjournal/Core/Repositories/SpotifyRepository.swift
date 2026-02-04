//
//  SpotifyRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

import Foundation
import Supabase

protocol SpotifyRepositoryProtocol {
    func searchSongs(query: String) async throws -> [SpotifySong]
    func searchArtist(query: String) async throws -> [SpotifyArtist]
}

class BFFSpotifyRepository: SpotifyRepositoryProtocol {
    
    private let client: BFFClient
    
    init(client: BFFClient) {
        self.client = client
    }

    func searchSongs(query: String) async throws -> [SpotifySong] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/spotify/search/tracks?q=\(encoded)")
    }

    func searchArtist(query: String) async throws -> [SpotifyArtist] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.get("/spotify/search/trtists?q=\(encoded)")
    }
}


//func fetchAccessToken() async throws -> String {
//    if let cachedToken, let tokenExpiry, tokenExpiry > Date() {
//        return cachedToken
//    }
//
//    let response: SpotifyTokenResponse = try await supabaseClient.client.functions
//        .invoke("smart-worker")
//
//    self.cachedToken = response.accessToken
//    self.tokenExpiry = Date().addingTimeInterval(50 * 60)
//
//    return response.accessToken
//}
//
//func searchSongs(query: String) async throws -> [SpotifySong] {
//    let token = try await fetchAccessToken()
//
//    let url = URL(string: "https://api.spotify.com/v1/search?q=\(query)&type=track&limit=20")!
//    var request = URLRequest(url: url)
//    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//    let (data, _) = try await URLSession.shared.data(for: request)
//    let response = try JSONDecoder().decode(SpotifySongsSearchResponse.self, from: data)
//
//    return response.tracks?.items ?? []
//}
//
//func searchArtist(query: String) async throws -> [SpotifyArtist] {
//    let token = try await fetchAccessToken()
//
//    let url = URL(string: "https://api.spotify.com/v1/search?q=\(query)&type=artist&limit=20")!
//
//    var request = URLRequest(url: url)
//            request.httpMethod = "GET"
//            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//    let (data, _) = try await URLSession.shared.data(for: request)
//    let result = try JSONDecoder().decode(SpotifyArtistSearchResponse.self, from: data)
//
//    return result.artists.items
//}
