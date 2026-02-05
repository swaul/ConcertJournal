import Foundation
import Combine
import Supabase
import SwiftUI

@MainActor
@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var newPasswordRepeat: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private let supabaseClient: SupabaseClientManagerProtocol
    private let userSessionManager: UserSessionManagerProtocol

    init(supabaseClient: SupabaseClientManagerProtocol, userSessionManager: UserSessionManagerProtocol) {
        self.supabaseClient = supabaseClient
        self.userSessionManager = userSessionManager
        Task { await refreshSessionState() }
    }

    func signInWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
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
            print(result)
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
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let provider: Provider = .spotify
            let redirectTo = URL(string: supabaseClient.redirectURLString)!
            _ = try await supabaseClient.client.auth.signInWithOAuth(provider: provider, redirectTo: redirectTo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSessionState() async {
        do {
            try await userSessionManager.start()
        } catch {
            print("Login failed")
        }
    }
}
