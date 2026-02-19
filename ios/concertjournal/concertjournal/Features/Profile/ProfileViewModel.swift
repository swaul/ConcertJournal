//
//  ProfileViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Observation
import Supabase


struct Profile: Decodable {
    let email: String?
    let displayName: String?
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

@Observable
final class ProfileViewModel {
    var profile: Profile? = nil
    
    var loadingState: ProfileState = .loading
    var saveDisplayNameState: ProfileState = .loaded
    
    let userProvider: UserSessionManagerProtocol
    let supabaseClient: SupabaseClientManagerProtocol

    init(supabaseClient: SupabaseClientManagerProtocol,
         userProvider: UserSessionManagerProtocol) {
        self.userProvider = userProvider
        self.supabaseClient = supabaseClient
    }

    @MainActor
    func load() async {
        do {
            loadingState = .loading
            if let user = userProvider.user {
                try await loadProfile(for: user)
                loadingState = .loaded
            } else {
                let user = try await userProvider.loadUser()
                try await loadProfile(for: user)
                loadingState = .loaded
            }
        } catch let error as UserError {
            loadingState = .loaded
        } catch {
            loadingState = .error
            print("ERROR LOADING USER DATA")
        }
    }
    
    private func loadProfile(for user: User) async throws {
        let profile: Profile = try await supabaseClient.client
            .from("profiles")
            .select("*")
            .eq("id", value: user.id)
            .execute()
            .value
        
        self.profile = profile
    }
    
    // Justin.shima@appsflyer.com
    
    func signOut() {
        Task { @MainActor in
            do {
                _ = try await supabaseClient.client.auth.signOut()
                try await userProvider.start()
            } catch {
                print(error)
            }
        }
    }
}
