//
//  SupabaseClient.swift
//  concertjournal
//
//  Wrapper für Supabase Client - ersetzt das Singleton Pattern
//

import Foundation
import Supabase

/// Konfiguration für Supabase
struct SupabaseConfig {
    let url: URL
    let anonKey: String
    let redirectURL: String

    static let production = SupabaseConfig(
        url: URL(string: "https://brjekjxckpdlwffcdndn.supabase.co")!,
        anonKey: "sb_publishable_9arAE6MQR0Cj0m-jE3lXCQ_BfNy0PK7",
        redirectURL: "concertjournal://auth-callback"
    )
}

/// Manager für Supabase Client
class SupabaseClientManager {

    let client: SupabaseClient
    let config: SupabaseConfig
    let redirectURLString: String = "concertjournal://auth-callback"

    init(config: SupabaseConfig = .production) {
        self.config = config
        self.client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey
        )
    }

    // MARK: - Auth Helpers

    var currentUser: User? {
        client.auth.currentUser
    }

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    func handleAuthCallback(from url: URL) async throws {
        try await client.auth.session(from: url)
    }
}
