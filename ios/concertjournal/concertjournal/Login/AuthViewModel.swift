import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false

    private let client: SupabaseClient

    init() {
        self.client = SupabaseManager.shared.client
        Task { await refreshSessionState() }
    }

    func signInWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            // If you use email+password auth in Supabase Auth (email provider enabled), use signIn with email+password
            _ = try await client.auth.signIn(email: email, password: password)
            await refreshSessionState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            await refreshSessionState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.signOut()
            await refreshSessionState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithSpotify() async {
        // Placeholder: You need to configure a redirect URI in your app and in Supabase Auth (Auth Providers -> Spotify)
        // Then call signIn with .spotify provider. On iOS, you'll typically use a URL scheme and handle the callback in SceneDelegate.
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let provider: Provider = .spotify
            // Replace with your custom redirect URL registered with Supabase and your app (e.g., com.your.bundle://auth-callback)
            let redirectTo = URL(string: SupabaseManager.shared.redirectURLString)!
            _ = try await client.auth.signInWithOAuth(provider: provider, redirectTo: redirectTo)
            // The flow will continue via the incoming URL callback.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSessionState() async {
        do {
            let session = try await client.auth.session
            isAuthenticated = session.user != nil
        } catch {
            isAuthenticated = false
        }
    }
}
