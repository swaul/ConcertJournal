//
//  CreateSetlistView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 26.12.25.
//

import Combine
import SwiftUI
import Supabase

struct CreateSetlistView: View {
    @EnvironmentObject var navigationManager: NavigationManager
    
    @StateObject var viewModel = CreateSetlistViewModel()
    
    @State var songName: String = ""
    @State var hasText: Bool = false
    
    @State var selectedSong: String? = nil
    
    @FocusState var textFieldFocused: Bool
    
    @Namespace var selection
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch viewModel.songLoadingState {
                    case .idle:
                        EmptyView()
                    case .loading:
                        ProgressView()
                    case .loaded(let songResponse):
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(songResponse) { song in
                                Button {
                                    selectedSong = song.id
                                } label: {
                                    makeSongView(song: song)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    case .error(let error):
                        Text(error.localizedDescription)
                    }
                }
                .padding()
            }
            .toolbar {
                if selectedSong != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            //                        guard let artist = viewModel.songResponse.first(where: { $0.id == selectedSong }) else { return }
                            //                        navigationManager.push(view: .createVisit(CreateConcertVisitViewModel(artist: artist)))
                        } label: {
                            Text("Next")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField(text: $songName) {
                        Text("Select a Song")
                    }
                    .focused($textFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.searchSongs(with: songName)
                        textFieldFocused = false
                    }
                    .onChange(of: songName) { _, newValue in
                        withAnimation {
                            hasText = !newValue.isEmpty
                        }
                    }
                    .padding()
                    .glassEffect()
                    
                    if hasText {
                        Button {
                            viewModel.searchSongs(with: songName)
                            textFieldFocused = false
                        } label: {
                            Text("Search")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    textFieldFocused = true
                }
            }
            .navigationTitle("Add a Song")
        }
    }
    
    func makeSongView(song: SpotifySong) -> some View {
        HStack {
            Group {
                AsyncImage(url: song.albumCover, content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                }, placeholder: {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 60)
                })
            }
            .clipShape(.circle)
            .frame(width: 60, height: 60)
            .padding()
            
            VStack(alignment: .leading) {
                Text(song.name)
                    .bold()
                    .lineLimit(1)
                Text(song.album?.name ?? "Album")
                    .lineLimit(1)
            }
            .padding(.vertical)
            .padding(.trailing)
            
            Spacer()
        }
        .selectedGlass(selected: selectedSong == song.id)
    }
    
}

enum CreateSetlistStatw {
    case idle
    case loading
    case loaded([SpotifySong])
    case error(Error)
}

class CreateSetlistViewModel: ObservableObject {
    
    @Published var songLoadingState: CreateSetlistStatw = .idle

    struct SpotifyTokenResponse: Codable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    func fetchSpotifyToken() async throws -> String {
        let response: SpotifyTokenResponse = try await SupabaseManager.shared.client.functions
          .invoke("smart-worker")
        
        return response.accessToken
    }
    
    func searchSongs(with text: String) {
        Task {
            do {
                songLoadingState = .loading
                guard let url = makeSpotifySearchURL(query: text) else {
                    songLoadingState = .error(URLError(.badURL))
                    throw URLError(.badURL)
                }
                
                let token = try await fetchSpotifyToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(SpotifySongsSearchResponse.self, from: data)
                songLoadingState = .loaded(result.tracks?.items ?? [])
            } catch {
                print("Could not complete search for \(text);", error)
                songLoadingState = .error(URLError(.badURL))
            }
        }
    }
    
    func makeSpotifySearchURL(query: String,
                              limit: Int = 10) -> URL? {

        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "market", value: "DE")
        ]

        return components?.url
    }
}

#Preview {
    CreateSetlistView()
}
