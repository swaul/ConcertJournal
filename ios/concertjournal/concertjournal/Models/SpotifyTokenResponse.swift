//
//  SpotifyTokenResponse.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.01.26.
//

struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
