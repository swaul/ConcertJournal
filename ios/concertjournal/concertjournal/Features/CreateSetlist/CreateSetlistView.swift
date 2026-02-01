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
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State private var viewModel: CreateSetlistViewModel?
    @State var songName: String = ""
    @State var hasText: Bool = false
    
    @State var selectedSong: String? = nil
    
    @FocusState var textFieldFocused: Bool
    
    @Namespace var selection
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .toolbar {
                if selectedSong != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            //                        guard let artist = viewModel.songResponse.first(where: { $0.id == selectedSong }) else { return }
                            //                        navigationManager.push(view: .createVisit(CreateConcertVisitViewModel(artist: artist)))
                        } label: {
                            Text("Next")
                                .font(.cjBody)
                        }
                    }
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = CreateSetlistViewModel(spotifyRepository: dependencies.spotifyRepository)
            }
            .navigationTitle("Add a Song")
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: CreateSetlistViewModel) -> some View {
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
                        .font(.cjBody)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField(text: $songName) {
                    Text("Select a Song")
                        .font(.cjBody)
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
                            .font(.cjBody)
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
    }

    @ViewBuilder
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
                    .font(.cjBody)
                    .bold()
                    .lineLimit(1)
                Text(song.album?.name ?? "Album")
                    .font(.cjBody)
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
