import Foundation
import Combine
import Supabase
import SwiftUI

// MARK: - Auth View Model

@MainActor
@Observable
final class AuthViewModel {

    // MARK: - Published Properties

    var email: String = ""
    var password: String = ""
    var newPasswordRepeat: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClientManagerProtocol
    private let userSessionManager: UserSessionManagerProtocol

    // MARK: - Initialization

    init(
        supabaseClient: SupabaseClientManagerProtocol,
        userSessionManager: UserSessionManagerProtocol
    ) {
        self.supabaseClient = supabaseClient
        self.userSessionManager = userSessionManager
    }

    // MARK: - Email Authentication

    func signInWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await supabaseClient.client.auth.signIn(
                email: email,
                password: password
            )
            await refreshSessionState()
        } catch {
            logError("Email sign in failed", error: error, category: .auth)
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await supabaseClient.client.auth.signUp(
                email: email,
                password: password
            )
            logInfo("Sign up successful: \(result.user.email ?? "unknown")", category: .auth)
            await refreshSessionState()
        } catch {
            logError("Email sign up failed", error: error, category: .auth)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Spotify OAuth

    func signInWithSpotify() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let scopes = [
            "user-read-email",
            "playlist-read-private",
            "playlist-read-collaborative",
            "playlist-modify-public",
            "playlist-modify-private",
            "user-library-read"
        ].joined(separator: " ")

        do {
            guard let redirectURL = URL(string: supabaseClient.redirectURLString) else {
                throw AuthError.invalidRedirectURL
            }

            let session = try await supabaseClient.client.auth.signInWithOAuth(
                provider: .spotify,
                redirectTo: redirectURL,
                scopes: scopes
            )

            logInfo("Spotify OAuth initiated", category: .auth)
            try await userSessionManager.start()

        } catch {
            logError("Spotify OAuth failed", error: error, category: .auth)
            errorMessage = "Failed to connect Spotify: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabaseClient.client.auth.signOut()
            await refreshSessionState()
            logInfo("User signed out", category: .auth)
        } catch {
            logError("Sign out failed", error: error, category: .auth)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Password reset
    
    func passwordReset(email: String?) {
        
    }

    // MARK: - Private Methods

    private func refreshSessionState() async {
        do {
            try await userSessionManager.start()
        } catch {
            logError("Failed to refresh session state", error: error, category: .auth)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidRedirectURL

    var errorDescription: String? {
        switch self {
        case .invalidRedirectURL:
            return "Invalid redirect URL configuration"
        }
    }
}

// MARK: - Create Playlist Button

struct CreatePlaylistButton: View {

    @Environment(\.dependencies) var dependencies

    @State var viewModel: ConcertDetailViewModel
    @State private var showingSuccess = false

    var body: some View {
        Button {
            Task {
                try await viewModel.createSpotifyPlaylist(spotifyRepository: dependencies.spotifyRepository,
                                                          userSessionManager: dependencies.userSessionManager)
            }
        } label: {
            HStack {
                Image("Spotify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)

                Text("Create Playlist")
                    .font(.cjBody)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(6)
        .background { Color.black }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .disabled(viewModel.isLoading)
        .alert("Playlist Created", isPresented: $showingSuccess) {
            Button("OK") { }

            if let url = viewModel.createdPlaylistURL,
               let spotifyURL = URL(string: url) {
                Button("Open in Spotify") {
                    UIApplication.shared.open(spotifyURL)
                }
                .font(.cjBody)
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}

// MARK: - Spotify Playlist Picker

struct SpotifyPlaylistPicker: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencies) var dependencies

    @StateObject private var viewModel = PlaylistPickerViewModel()
    @State private var searchText: String = ""
    @FocusState private var searchFieldFocused

    var onSelect: (SpotifyPlaylist) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                Group {
                    if viewModel.isLoading {
                        ProgressView("Lade Playlists...")
                            .font(.cjBody)
                    } else if viewModel.playlists.isEmpty {
                        ContentUnavailableView(
                            "Keine Playlists",
                            systemImage: "music.note.list",
                            description: Text("Du hast keine playlists auf Spotify. Speichere eine Playlist in deinem Spotify Account um sie hier zu importieren")
                        )
                        .font(.cjBody)
                    } else {
                        List(viewModel.playlists) { playlist in
                            Button {
                                HapticManager.shared.navigationTap()
                                onSelect(playlist)
                                dismiss()
                            } label: {
                                PlaylistRow(playlist: playlist)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !viewModel.isLoading {
                    HStack {
                        TextField("Playlist suchen", text: $searchText)
                            .focused($searchFieldFocused)
                            .submitLabel(.search)
                            .font(.cjBody)
                            .padding()
                            .glassEffect()

                        Button {
                            Task {
                                HapticManager.shared.buttonTap()
                                await viewModel.searchPlaylists(
                                    query: searchText,
                                    spotifyRepository: dependencies.spotifyRepository
                                )
                            }
                        } label: {
                            Text("Suchen")
                                .font(.cjBody)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Import aus Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .font(.cjBody)
                }
            }
            .task {
                await viewModel.loadPlaylists(
                    spotifyRepository: dependencies.spotifyRepository
                )
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
                    .font(.cjBody)
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.cjBody)
                }
            }
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: SpotifyPlaylist

    var body: some View {
        HStack(spacing: 12) {
            // Playlist Image
            if let imageURL = playlist.images?.first?.url,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.cjBody)
                    .lineLimit(1)

                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.cjFootnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text("\(playlist.tracks.total) tracks")
                    .font(.cjCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Playlist Picker View Model

@MainActor
class PlaylistPickerViewModel: ObservableObject {

    @Published var playlists: [SpotifyPlaylist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadPlaylists(spotifyRepository: SpotifyRepositoryProtocol) async {
        isLoading = true
        defer { isLoading = false }

        do {
            playlists = try await spotifyRepository.getUserPlaylists(limit: 50)
            logSuccess("Loaded \(playlists.count) playlists", category: .viewModel)
        } catch {
            errorMessage = "Failed to load playlists: \(error.localizedDescription)"
            logError("Load playlists failed", error: error, category: .viewModel)
        }
    }

    func searchPlaylists(
        query: String,
        spotifyRepository: SpotifyRepositoryProtocol
    ) async {
        guard !query.isEmpty else {
            // If query is empty, reload user playlists
            await loadPlaylists(spotifyRepository: spotifyRepository)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            playlists = try await spotifyRepository.searchPlaylists(query: query, limit: 20)
            logSuccess("Found \(playlists.count) playlists", category: .viewModel)
        } catch {
            errorMessage = "Failed to search playlists: \(error.localizedDescription)"
            logError("Search playlists failed", error: error, category: .viewModel)
        }
    }
}
