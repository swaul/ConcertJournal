//
//  CreateConcertSelectArtistViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

import Combine
import SpotifyiOS
import Supabase

class CreateConcertSelectArtistViewModel: ObservableObject {
    
    @Published var artistsResponse: [SpotifyArtist] = []

    struct SpotifyTokenResponse: Codable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    func fetchSpotifyToken() async throws -> String {
        let response: SpotifyTokenResponse = try await SupabaseManager.shared.client.functions
          .invoke("smart-worker")
        
        return response.accessToken
    }
    
    func searchArtists(with text: String) {
        Task {
            do {
                guard let url = makeSpotifySearchURL(query: text) else {
                    throw URLError(.badURL)
                }
                
                let token = try await fetchSpotifyToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(SpotifyArtistSearchResponse.self, from: data)
                artistsResponse = result.artists.items
            } catch {
                print("Could not complete search for \(text);", error)
            }
        }
    }
    
    func makeSpotifySearchURL(query: String,
                              limit: Int = 10) -> URL? {

        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "artist"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "market", value: "DE")
        ]

        return components?.url
    }
}
