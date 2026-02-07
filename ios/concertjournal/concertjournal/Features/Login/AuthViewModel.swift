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
        let scopes = "user-read-email playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private user-library-read"

        do {
            let provider: Provider = .spotify
            let redirectTo = URL(string: supabaseClient.redirectURLString)!
            _ = try await supabaseClient.client.auth.signInWithOAuth(provider: provider, redirectTo: redirectTo, scopes: scopes)
            
            logInfo("Spotify OAuth initiated", category: .auth)
            try await userSessionManager.start()
          } catch {
              logError("Spotify OAuth failed", error: error, category: .auth)
              errorMessage = "Failed to connect Spotify: \(error.localizedDescription)"
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

// =============================================================================
// iOS Implementation Examples - Spotify Playlist Features
// =============================================================================

import Foundation
import SwiftUI

// =============================================================================
// MARK: - Response Types
// =============================================================================

struct CreatePlaylistResponse: Codable {
    let success: Bool
    let playlist: PlaylistInfo
    
    struct PlaylistInfo: Codable {
        let id: String
        let name: String
        let url: String
    }
}

struct ImportPlaylistResponse: Codable {
    let success: Bool
    let message: String
    let imported: Int
    let skipped: Int
    let items: [SetlistItem]
}

struct SpotifyPlaylistsResponse: Codable {
    let total: Int
    let playlists: [SpotifyPlaylist]
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let tracks_total: Int
    let images: [SpotifyImage]?
    
    struct SpotifyImage: Codable {
        let url: String
    }
}

// =============================================================================
// MARK: - ViewModel Extension
// =============================================================================

extension ConcertDetailViewModel {
    
    // =========================================================================
    // Create Spotify Playlist from Setlist
    // =========================================================================
    

}

// =============================================================================
// MARK: - Request Types
// =============================================================================

struct CreatePlaylistRequest: Codable {
    let concertId: String
    let playlistName: String
    let playlistDescription: String?
    let isPublic: Bool?
}

struct ImportPlaylistRequest: Codable {
    let concertId: String
    let playlistId: String
}

struct CreatePlaylistButton: View {
    
    @Environment(\.dependencies) var dependencies
    
    @State var viewModel: ConcertDetailViewModel
    @State private var showingSuccess = false
    
    var body: some View {
        Button {
            Task {
                await viewModel.createSpotifyPlaylist(token: dependencies.userSessionManager.session?.providerToken)
            }
        } label: {
            HStack {
                Image("Spotify")
                    .resizable()
                    .frame(height: 32)
                Text("Create Playlist")
                    .font(.cjBody)
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .padding(6)
        .background { Color.black }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .disabled(viewModel.isLoading || viewModel.setlistItems?.isEmpty == true)
        .alert("Playlist Created", isPresented: $showingSuccess) {
            Button("OK") { }
            if let url = viewModel.createdPlaylistURL,
               let spotifyURL = URL(string: url) {
                Button("Open in Spotify") {
                    UIApplication.shared.open(spotifyURL)
                }
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}

// =========================================================================
// Import Playlist Picker
// =========================================================================

struct SpotifyPlaylistPicker: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PlaylistPickerViewModel()
    
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading playlists...")
                } else if viewModel.playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "music.note.list",
                        description: Text("You don't have any Spotify playlists yet")
                    )
                } else {
                    List(viewModel.playlists) { playlist in
                        PlaylistRow(playlist: playlist)
                            .onTapGesture {
                                onSelect(playlist.id)
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle("Import from Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPlaylists()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

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
                
                Text("\(playlist.tracks_total) tracks")
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

// =========================================================================
// Playlist Picker ViewModel
// =========================================================================

@MainActor
class PlaylistPickerViewModel: ObservableObject {
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let bffClient: BFFClient
    
    init(bffClient: BFFClient = DependencyContainer().bffClient) {
        self.bffClient = bffClient
    }
    
    func loadPlaylists() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: SpotifyPlaylistsResponse = try await bffClient.request(
                method: "GET",
                path: "/spotify/playlists?limit=50"
            )
            playlists = response.playlists
        } catch {
            errorMessage = "Failed to load playlists"
            logError("Load playlists failed", error: error, category: .viewModel)
        }
    }
}

// =============================================================================
// MARK: - Usage in Concert Detail View
// =============================================================================

//struct ConcertDetailView: View {
//    @StateObject var viewModel: ConcertDetailViewModel
//    @State private var showPlaylistPicker = false
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                // ... existing concert details ...
//                
//                // Spotify Integration Section
//                VStack(spacing: 12) {
//                    Text("Spotify Integration")
//                        .font(.cjHeadline)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                    
//                    // Create Playlist Button
//                    CreatePlaylistButton(viewModel: viewModel)
//                    
//                    // Import Playlist Button
//                    Button {
//                        showPlaylistPicker = true
//                    } label: {
//                        HStack {
//                            Image(systemName: "square.and.arrow.down")
//                            Text("Import from Spotify")
//                                .font(.cjBody)
//                        }
//                        .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.bordered)
//                    .disabled(viewModel.isLoading)
//                }
//                .padding()
//                .background(Color(.systemGray6))
//                .cornerRadius(12)
//            }
//            .padding()
//        }
//        .sheet(isPresented: $showPlaylistPicker) {
//            SpotifyPlaylistPicker { playlistId in
//                Task {
//                    await viewModel.importPlaylistToSetlist(playlistId: playlistId)
//                }
//            }
//        }
//    }
//}
