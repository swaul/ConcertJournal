import Foundation
import Supabase
import Combine

@MainActor
final class UserSessionManager: ObservableObject {
    
    static let shared = UserSessionManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var authTask: Task<Void, Never>?

    init() {
        self.client = SupabaseManager.shared.client
    }

    func start() {
        // Initial fetch
        Task { await refreshSession() }
        // Subscribe to auth state changes
        authTask?.cancel()
        authTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.client.auth.authStateChanges {
                switch state.event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    await self.refreshSession()
                case .signedOut, .userDeleted:
                    self.currentUser = nil
                    self.isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    func stop() {
        authTask?.cancel()
        authTask = nil
    }

    func refreshSession() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = session.user != nil
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    // Convenience passthroughs (optional)
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
