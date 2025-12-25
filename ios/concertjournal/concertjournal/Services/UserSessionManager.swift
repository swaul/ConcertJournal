import Foundation
import Supabase
import Combine

enum UserContext {
    case loggedOut
    case initializing
    case loggedIn(User)
}

@MainActor
final class UserSessionManager: ObservableObject, UserProviding {
    
    @Published private(set) var session: Session?
    @Published private(set) var user: User?
    
    func start() async {
        let client = SupabaseManager.shared.client
        Task {
            let session = try await client.auth.session
            update(session: session)
            
            for await event in client.auth.authStateChanges {
                update(session: event.session)
            }
        }
    }
    
    private func update(session: Session?) {
        self.session = session
        self.user = session?.user
    }
    
    func loadUser() async throws -> User {
        let user = try await SupabaseManager.shared.client.auth.user()
        return user
    }
}
