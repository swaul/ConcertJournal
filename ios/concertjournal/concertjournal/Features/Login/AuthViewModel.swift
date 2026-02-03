import Foundation
import Combine
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var isAuthenticated: Bool = false

    private let supabaseClient: SupabaseClientManagerProtocol

    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
        Task { await refreshSessionState() }
    }

    func signInWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            // If you use email+password auth in Supabase Auth (email provider enabled), use signIn with email+password
            _ = try await supabaseClient.client.auth.signIn(email: email, password: password)
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
            let result = try await supabaseClient.client.auth.signUp(email: email, password: password)
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
            try await supabaseClient.client.auth.signOut()
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
            let redirectTo = URL(string: supabaseClient.redirectURLString)!
            _ = try await supabaseClient.client.auth.signInWithOAuth(provider: provider, redirectTo: redirectTo)
            // The flow will continue via the incoming URL callback.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSessionState() async {
        do {
            let session = try await supabaseClient.client.auth.session
            isAuthenticated = session.user != nil
        } catch {
            isAuthenticated = false
        }
    }
}
