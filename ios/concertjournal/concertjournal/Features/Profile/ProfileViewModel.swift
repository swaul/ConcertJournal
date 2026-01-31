//
//  ProfileViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Supabase

@Observable
final class ProfileViewModel {
    var initialDisplayName: String = ""
    var displayName: String = ""
    var email: String? = nil
    
    var loadingState: ProfileState = .loading
    var saveDisplayNameState: ProfileState = .loaded
    
    let userProvider: UserSessionManager
    let supabaseClient: SupabaseClientManager

    init(supabaseClient: SupabaseClientManager, userProvider: UserSessionManager) {
        self.userProvider = userProvider
        self.supabaseClient = supabaseClient
    }

    @MainActor
    func load() async {
        do {
            loadingState = .loading
            if let user = userProvider.user {
                loadingState = .loaded
                fillView(with: user)
            } else {
                let user = try await userProvider.loadUser()
                loadingState = .loaded
                fillView(with: user)
            }
        } catch {
            loadingState = .error
            print("ERROR LOADING USER DATA")
        }
    }
    
    private func fillView(with user: User) {
        email = user.email
        displayName = user.userMetadata["display_name"]?.stringValue ?? "Your name"
        initialDisplayName = displayName
    }
    
    func saveDisplayName() {
        Task {
            do {
                saveDisplayNameState = .loading
                let userAttributes = UserAttributes(data: ["display_name": .string(displayName)])
                try await supabaseClient.client.auth.update(user: userAttributes)
                saveDisplayNameState = .loaded
            } catch {
                saveDisplayNameState = .error
            }
        }
    }
    
    func signOut() {
        Task { @MainActor in
            do {
                _ = try await supabaseClient.client.auth.signOut()
            } catch {
                print(error)
            }
        }
    }
}
