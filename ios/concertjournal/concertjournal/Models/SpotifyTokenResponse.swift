//
//  SpotifyTokenResponse.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

struct SpotifyTokenResponse: Codable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
