import Foundation
import Supabase
import Combine

// MARK: - Protocol

protocol UserSessionManagerProtocol {
    var session: Session? { get }
    var user: User? { get }
    var userId: String? { get }
    var providerToken: String? { get }
    var providerRefreshToken: String? { get }

    var userSessionChanged: AnyPublisher<User?, Never> { get }
    var state: UserSessionState { get }

    func start() async throws
    func loadUser() async throws -> User
    func refreshSpotifyProviderTokenIfNeeded() async throws
    func ensureValidProviderToken() async throws -> String
    func spotifyAccessToken() async throws -> String
}

// MARK: - Errors

enum UserError: Error, LocalizedError {
    case notLoggedIn
    case noProviderToken
    case tokenRefreshFailed
    case notLinkedToSpotify

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "User is not logged in"
        case .noProviderToken:
            return "No Spotify provider token available"
        case .tokenRefreshFailed:
            return "Failed to refresh Spotify token"
        case .notLinkedToSpotify:
            return "User account is not linked to Spotify"
        }
    }
}

// MARK: - Session State

enum UserSessionState: Equatable {
    case loggedOut
    case initializing
    case loggedIn(User)
}

// MARK: - Manager Implementation

@MainActor
@Observable
final class UserSessionManager: UserSessionManagerProtocol {

    // MARK: - Published Properties

    private(set) var state: UserSessionState = .initializing
    private(set) var session: Session?
    private(set) var user: User?

    // MARK: - Computed Properties

    var userId: String? {
        user?.id.uuidString
    }

    var providerToken: String? {
        session?.providerToken
    }

    var providerRefreshToken: String? {
        session?.providerRefreshToken
    }

    var isSpotifyLinked: Bool {
        user?.identities?.contains(where: { $0.provider == "spotify" }) ?? false
    }

    // MARK: - Publishers

    var userSessionChanged: AnyPublisher<User?, Never> {
        userSessionChangedSubject.eraseToAnyPublisher()
    }

    let userSessionChangedSubject = PassthroughSubject<User?, Never>()
    
    // MARK: - Private Properties

    private let client: SupabaseClient
    private var authStateTask: Task<Void, Never>?

    // Token refresh lock to prevent concurrent refreshes
    private var isRefreshingToken = false

    // MARK: - Initialization

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Public Methods

    /// Starts the session manager and begins listening to auth state changes
    func start() async throws {
        logInfo("UserSessionManager.start()", category: .auth)
        state = .initializing

        // Get current session
        let currentSession: Session?
        if let session {
            logSuccess("Session found!", category: .auth)
            currentSession = session
        } else {
            logInfo("Trying to establish session", category: .auth)
            currentSession = try? await client.auth.session
        }

        // Update session state
        try await update(session: currentSession)

        // Start listening to auth state changes
        startAuthStateListener()
    }

    /// Ensures a valid provider token is available, refreshing if necessary
    func ensureValidProviderToken() async throws -> String {
        guard isSpotifyLinked else {
            throw UserError.notLinkedToSpotify
        }

        // Check if we need to refresh
        if session?.isExpired == true || providerToken == nil {
            try await refreshSpotifyProviderTokenIfNeeded()
        }

        guard let token = providerToken else {
            throw UserError.noProviderToken
        }

        return token
    }

    /// Refreshes the Spotify provider token if needed
    func refreshSpotifyProviderTokenIfNeeded() async throws {
        // Prevent concurrent refreshes
        guard !isRefreshingToken else {
            logInfo("Token refresh already in progress, waiting...", category: .auth)
            // Wait a bit and try again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard providerToken != nil else {
                throw UserError.tokenRefreshFailed
            }
            return
        }

        guard isSpotifyLinked else {
            logInfo("No spotify account linked", category: .auth)
            return
        }

        // Check if refresh is actually needed
        if let session = session, !session.isExpired, providerToken != nil {
            logInfo("Token still valid, no refresh needed", category: .auth)
            return
        }

        isRefreshingToken = true
        defer { isRefreshingToken = false }

        logInfo("Refreshing Spotify provider token", category: .auth)

        do {
            let newSession = try await client.auth.refreshSession()
            try await update(session: newSession)

            guard providerToken != nil else {
                throw UserError.tokenRefreshFailed
            }

            logSuccess("Spotify provider token refreshed successfully", category: .auth)
        } catch {
            logError("Failed to refresh Spotify provider token", error: error, category: .auth)
            throw UserError.tokenRefreshFailed
        }
    }

    /// Loads the current user
    func loadUser() async throws -> User {
        if let user = self.user {
            return user
        }

        do {
            let user = try await client.auth.user()
            self.user = user
            state = .loggedIn(user)
            return user
        } catch {
            state = .loggedOut
            throw UserError.notLoggedIn
        }
    }

    // MARK: - Private Methods

    /// Updates the current session
    private func update(session: Session?) async throws {
        logInfo("Updating UserSessionManager with userId: \(session?.user.id.uuidString ?? "No session")", category: .auth)
        self.session = session
        self.user = session?.user
        if let userId = session?.user.id {
            UserDefaults.standard.set(userId.uuidString, forKey: "currentUserId")
        }

        if let user = session?.user {
            state = .loggedIn(user)
            logInfo("User logged in: \(user.email ?? "unknown")", category: .auth)
        } else {
            state = .loggedOut
            logInfo("User logged out", category: .auth)
        }

        userSessionChangedSubject.send(self.user)
    }

    struct SpotifyToken {
        let accessToken: String
        let expiresAt: Date

        init(token: SpotifyTokenResponse) {
            accessToken = token.accessToken
            expiresAt = Date.now.addingTimeInterval(token.expiresIn)
        }
    }

    private var cachedToken: SpotifyToken?

    func spotifyAccessToken() async throws -> String {
        if let cachedToken, cachedToken.expiresAt < Date.now {
            return cachedToken.accessToken
        }

        let accessToken: SpotifyTokenResponse = try await client.functions.invoke("smart-worker")

        self.cachedToken = SpotifyToken(token: accessToken)

        return accessToken.accessToken
    }

    /// Starts listening to auth state changes
    private func startAuthStateListener() {
        // Cancel existing listener
        authStateTask?.cancel()

        // Start new listener
        authStateTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.client.auth.authStateChanges {
                // Check if task was cancelled
                if Task.isCancelled { break }

                await MainActor.run {
                    logInfo("Auth state change: \(event.event)", category: .auth)
                }

                do {
                    try await self.update(session: event.session)
                } catch {
                    logError("Failed to update session after auth change", error: error, category: .auth)
                }
            }
        }
    }
}
