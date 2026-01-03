//
//  CreateConcertSelectArtistView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

import SwiftUI

struct CreateConcertSelectArtistView: View {
    
    
    @StateObject var viewModel = CreateConcertSelectArtistViewModel()
    
    @Binding var isPresented: Bool
    
    var didSelectArtist: (Artist) -> Void?

    @State var artistName: String = ""
    @State var hasText: Bool = false
    
    @State var selectedArtist: String? = nil
    
    @FocusState var textFieldFocused: Bool
    
    @Namespace var selection
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.artistsResponse) { artist in
                        Button {
                            selectedArtist = artist.id
                        } label: {
                            makeArtistView(artist: artist)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .toolbar {
                if selectedArtist != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            guard let artist = viewModel.artistsResponse.first(where: { $0.id == selectedArtist }) else { return }
                            isPresented = false
                            didSelectArtist(Artist(artist: artist))
                        } label: {
                            Text("Next")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField(text: $artistName) {
                        Text("Select an artist")
                    }
                    .focused($textFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
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
                            viewModel.searchArtists(with: artistName)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    textFieldFocused = true
                }
            }
            .navigationTitle("Select an Artist")
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
            .frame(height: 80)
            .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(artist.name)
                    .bold()
                Text("Follower: \(artist.followers?.total ?? 0)")
            }
            .padding(.vertical)
            .padding(.trailing)
            
            Spacer()
        }
        .selectedGlass(selected: selectedArtist == artist.id)
    }
    
}
