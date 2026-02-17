//
//  CreateConcertSelectArtistView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

import SwiftUI

struct CreateConcertSelectArtistView: View {
    
    @Environment(\.dependencies) private var dependencies

    init(isPresented: Binding<Bool>, didSelectArtist: @escaping (Artist) -> Void) {
        self.didSelectArtist = didSelectArtist
        self._isPresented = isPresented
    }

    @State var viewModel: CreateConcertSelectArtistViewModel? = nil

    @Binding var isPresented: Bool
    
    var didSelectArtist: (Artist) -> Void?

    @State var artistName: String = ""
    @State var hasText: Bool = false

    @State var didSearch: Bool = false

    @State var selectedArtist: String? = nil
    
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
            .background {
                Color.background.ignoresSafeArea()
            }
            .navigationTitle("Select an Artist")
            .task {
                viewModel = CreateConcertSelectArtistViewModel(spotifyRepository: dependencies.spotifyRepository,
                                                               offlineConcertRepository: dependencies.offlineConcertRepository)
            }
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: CreateConcertSelectArtistViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !didSearch {
                    ForEach(viewModel.currentArtists) { artist in
                        Button {
                            HapticManager.shared.buttonTap()
                            selectedArtist = artist.id.uuidString
                        } label: {
                            makeKnownArtistView(artist: artist)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(viewModel.artistsResponse) { artist in
                        Button {
                            HapticManager.shared.buttonTap()
                            selectedArtist = artist.id
                        } label: {
                            makeArtistView(artist: artist)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            if selectedArtist != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.buttonTap()
                        selectArtist(viewModel: viewModel)
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField(text: $artistName) {
                    Text("Select an artist")
                        .font(.cjBody)
                }
                .focused($textFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    HapticManager.shared.navigationTap()
                    viewModel.searchArtists(with: artistName)
                    textFieldFocused = false
                }
                .onChange(of: artistName) { _, newValue in
                    withAnimation {
                        hasText = !newValue.isEmpty
                    }
                }
                .padding()
                .glassEffect()

                if hasText {
                    Button {
                        HapticManager.shared.buttonTap()
                        viewModel.searchArtists(with: artistName)
                        textFieldFocused = false
                        didSearch = true
                    } label: {
                        Text("Search")
                            .font(.cjBody)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal)
        }
    }

    func makeArtistView(artist: SpotifyArtist) -> some View {
        HStack {
            Group {
                if let url = artist.firstImageURL {
                    AsyncImage(url: url) { result in
                        result.image?
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80)
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .frame(width: 80, height: 80)
                            .background { Color.gray }
                        Image(systemName: "note")
                            .frame(width: 32)
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipShape(.circle)
            .frame(width: 80, height: 80)
            .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(artist.name)
                    .font(.cjBody)
                    .bold()
                Text("Follower: \(artist.followers?.total ?? 0)")
                    .font(.cjBody)
            }
            .padding(.vertical)
            .padding(.trailing)
            
            Spacer()
        }
        .selectedGlass(selected: selectedArtist == artist.id)
    }

    func makeKnownArtistView(artist: Artist) -> some View {
        HStack {
            Group {
                if let url = artist.imageUrl {
                    AsyncImage(url: URL(string: url)) { result in
                        result.image?
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80)
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .frame(width: 80, height: 80)
                            .background { Color.gray }
                        Image(systemName: "note")
                            .frame(width: 32)
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipShape(.circle)
            .frame(width: 80, height: 80)
            .padding()

            Text(artist.name)
                .font(.cjBody)
                .bold()
            .padding(.vertical)
            .padding(.trailing)

            Spacer()
        }
        .selectedGlass(selected: selectedArtist == artist.id.uuidString)
    }


    private func selectArtist(viewModel: CreateConcertSelectArtistViewModel) {
        do {
            if let artist = viewModel.artistsResponse.first(where: { $0.id == selectedArtist }) {
                let savedArtist = try dependencies.offlineConcertRepository.presaveArtist(ArtistDTO(artist: artist))
                didSelectArtist(savedArtist)
                isPresented = false
            } else if let artist = viewModel.currentArtists.first(where: { $0.id.uuidString == selectedArtist }) {
                didSelectArtist(artist)
                isPresented = false
            }
        } catch {
            logError("Selecting artist failed", error: error)
        }
    }
}
