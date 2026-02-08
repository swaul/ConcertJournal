import Foundation
import Supabase
import Combine

protocol UserSessionManagerProtocol {
    var session: Session? { get }
    var user: User? { get }
    var userId: String? { get }
    
    var userSessionChanged: AnyPublisher<User?, Never> { get }

    func start() async throws
    func loadUser() async throws -> User
}

enum UserError: Error {
    case notLoggedIn
}

enum UserContext {
    case loggedOut
    case initializing
    case loggedIn(User)
}

@MainActor
@Observable
final class UserSessionManager: UserSessionManagerProtocol {
    
    var userSessionChanged: AnyPublisher<User?, Never> {
        userSessionChangedSubject.eraseToAnyPublisher()
    }
    
    let userSessionChangedSubject = PassthroughSubject<User?, Never>()
    
    private(set) var session: Session?
    private(set) var user: User?
    
    var userId: String? {
        user?.id.uuidString
    }

    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func start() async throws {
        let session = try await client.auth.session
        try await update(session: session)

        for await event in client.auth.authStateChanges {
            try await update(session: event.session)
        }
    }
    
    private func update(session: Session?) async throws {
        self.session = session
        self.user = session?.user

        userSessionChangedSubject.send(session?.user)

        guard let session else { return }
        try await storeSpotifyProviderToken(with: session)
    }
    
    func loadUser() async throws -> User {
        let user = try await client.auth.user()
        return user
    }
}
