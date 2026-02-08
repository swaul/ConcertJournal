//
//  SupabaseClient.swift
//  concertjournal
//
//  Wrapper für Supabase Client - ersetzt das Singleton Pattern
//

import Foundation
import Supabase

protocol SupabaseClientManagerProtocol {
    var client: SupabaseClient { get }
    var currentUser: User? { get }
    var currentUserId: UUID? { get }
    var redirectURLString: String { get }

    func handleAuthCallback(from url: URL) async throws
}

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

class SupabaseClientManager: SupabaseClientManagerProtocol {

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

extension UserSessionManager {

    /// Store Spotify provider token in user_metadata
    /// Call this after successful Spotify OAuth login
    func storeSpotifyProviderToken(with session: Session) async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 Storing Spotify Provider Token...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Session found for user: \(session.user.id)")
        print("   Email: \(session.user.email ?? "unknown")")

        // 2. Find Spotify identity
        guard let spotifyIdentity = session.user.identities?.first(where: { $0.provider == "spotify" }) else {
            print("⚠️ No Spotify identity found")
            throw StoreTokenError.noSpotifyIdentity
        }

        print("✅ Spotify identity found")
        print("   Identity ID: \(spotifyIdentity.id)")

        // 3. Extract provider token
        print("📋 Checking identity data...")
        print("   Available keys: \(spotifyIdentity.identityData?.keys.sorted() ?? [])")

        var providerToken: String?

        // Try different possible keys
        if let token = spotifyIdentity.identityData?["provider_token"] as? String {
            providerToken = token
            print("✅ Found provider_token")
        } else if let token = spotifyIdentity.identityData?["access_token"] as? String {
            providerToken = token
            print("✅ Found access_token (using as provider_token)")
        } else if let token = session.providerToken {
            providerToken = token
            print("✅ Found provider_token (using general providerToken from session)")
        }

        guard let token = providerToken else {
            print("❌ No provider token found in identity data")
            print("   Full identity data: \(spotifyIdentity.identityData ?? [:])")
            throw StoreTokenError.noProviderToken
        }

        print("✅ Provider token extracted")
        print("   Token preview: \(token.prefix(30))...")
        print("   Token length: \(token.count) characters")

        // 4. Store in user_metadata
        print("💾 Storing token in user_metadata...")

        do {
            let updatedUser = try await client.auth.update(
                user: UserAttributes(
                    data: [
                        "spotify_provider_token": .string(token)
                    ]
                )
            )

            print("✅ Token stored successfully!")
            print("   User metadata updated: \(updatedUser.userMetadata)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {
            print("❌ Failed to store token: \(error)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            throw error
        }
    }
}

enum StoreTokenError: LocalizedError {
    case noSpotifyIdentity
    case noProviderToken

    var errorDescription: String? {
        switch self {
        case .noSpotifyIdentity:
            return "No Spotify identity found. Please log in with Spotify first."
        case .noProviderToken:
            return "No provider token found in Spotify identity data."
        }
    }
}
