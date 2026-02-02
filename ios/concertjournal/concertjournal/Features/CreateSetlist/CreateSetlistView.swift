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

    var onSave: ([TempCeateSetlistItem]) -> Void

    @State var path = NavigationPath()

    @State private var viewModel: CreateSetlistViewModel
    @State var songName: String = ""
    @State var hasText: Bool = false
    @State private var deleteSongDialog: Bool = false {
        didSet {
            if deleteSongDialog == false {
                songToDelete = nil
            }
        }
    }
    @State private var songToDelete: String? = nil

    @FocusState var textFieldFocused: Bool
    
    @Namespace var selection

    init(viewModel: CreateSetlistViewModel, onSave: @escaping ([TempCeateSetlistItem]) -> Void) {
        self.viewModel = viewModel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack(path: $path) {
            viewWithViewModel(viewModel: viewModel)
            .toolbar {
                if !viewModel.selectedSongs.isEmpty{
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            path.append(NavigationRoute.orderSetlist(viewModel))
                        } label: {
                            Text("Next")
                                .font(.cjBody)
                        }
                    }
                }
            }
            .navigationTitle("Add a Song")
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .orderSetlist(let viewModel):
                    OrderSetListView(viewModel: viewModel)
                default:
                    Text("Not implemented")
                }
            }
            .onReceive(viewModel.didSaveSetlistPublisher) { setlistItems in
                onSave(setlistItems)
            }
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: CreateSetlistViewModel) -> some View {
        VStack {
            if !viewModel.selectedSongs.isEmpty {
                selectedSongsSection()
            }

            CJDivider(title: "Suche nach Songs", image: Image(systemName: "magnifyingglass"))
                .padding(.horizontal)

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
                                    didSelectSong(song)
                                } label: {
                                    makeSongView(song: song, viewModel: viewModel)
                                }
                                .buttonStyle(.plain)
                                .transition(.slide)
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
                searchTextField()
                .padding(.horizontal)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    textFieldFocused = true
                }
            }
        }
    }

    func didSelectSong(_ song: SpotifySong) {
        withAnimation {
            if let indexToRemove = viewModel.selectedSongs.firstIndex(where: { $0.id == song.id }) {
                viewModel.selectedSongs.remove(at: indexToRemove)
            } else {
                viewModel.selectedSongs.append(song)
            }
        }
    }

    @ViewBuilder
    func searchTextField() -> some View {
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

    }

    @ViewBuilder
    func makeSongView(song: SpotifySong, viewModel: CreateSetlistViewModel) -> some View {
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
        .selectedGlass(selected: viewModel.selectedSongs.contains(where: { $0.id == song.id }))
    }

    @ViewBuilder
    func selectedSongsSection() -> some View {
        VStack {
            CJDivider(title: "Hinzugefügte Songs", image: nil)
                .padding(.horizontal)
            VStack {
                ScrollView {
                    ForEach(viewModel.selectedSongs, id: \.id) { song in
                        HStack {
                            Text(song.name)
                            Spacer()
                            Button {
                                songToDelete = song.id
                                deleteSongDialog = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background {
                            if song.id == songToDelete {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(dependencies.colorThemeManager.appTint)
                            }
                        }
                        .confirmationDialog("Diesen Song löschen", isPresented: $deleteSongDialog, titleVisibility: .visible) {
                            Button(role: .destructive) {
                                guard let songToDelete else { return }
                                withAnimation {
                                    viewModel.selectedSongs.removeAll(where: { $0.id == songToDelete })
                                }
                                self.songToDelete = nil
                            } label: {
                                Text("Ja, song entfernen")
                            }

                            Button {
                                songToDelete = nil
                            } label: {
                                Text("Abbrechen")
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }
}

enum CreateSetlistStatw {
    case idle
    case loading
    case loaded([SpotifySong])
    case error(Error)
}
