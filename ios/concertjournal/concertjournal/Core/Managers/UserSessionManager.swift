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

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func start() async throws {
        let session = try await client.auth.session
        update(session: session)
            
        for await event in client.auth.authStateChanges {
            update(session: event.session)
        }
    }
    
    private func update(session: Session?) {
        self.session = session
        self.user = session?.user
        
        userSessionChangedSubject.send(session?.user)
    }
    
    func loadUser() async throws -> User {
        let user = try await client.auth.user()
        return user
    }
}
