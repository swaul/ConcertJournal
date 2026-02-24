//
//  EditConcertView+Setlist.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI
#if DEBUG
import CoreData
#endif

extension ConcertEditView {

    @ViewBuilder
    var setlistSection: some View {
        VStack(alignment: .leading) {
            if !setlistItems.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(setlistItems.enumerated(), id: \.element.id) { index, item in
                        makeEditSongView(index: index, song: item)
                    }
                }
                .padding()
                .rectangleGlass()

                Button {
                    HapticManager.shared.buttonTap()
                    editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)

                } label: {
                    Text(TextKey.editSetlist.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
            } else {
                Button {
                    HapticManager.shared.buttonTap()
                    editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)
                } label: {
                    Text(TextKey.addSetlist.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
            }
        }
    }

    @ViewBuilder
    func makeEditSongView(index: Int, song: TempCeateSetlistItem) -> some View {
            Grid(verticalSpacing: 8) {
                GridRow {
                    Text("\(index + 1).")
                        .font(.cjTitle2)
                        .frame(width: 28)
                    Text(song.title)
                        .font(.cjHeadline)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Rectangle().fill(.clear)
                        .frame(width: 28, height: 1)

                    Text(song.artistNames)
                        .font(.cjBody)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
    }
    
    func importPlaylistToSetlist() async throws {
        logInfo("Provider token found, loading playlists", category: .viewModel)

        let playlists = try await dependencies.spotifyRepository.getUserPlaylists(limit: 50)
        print(playlists)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var presenting: Bool = true

    let context = PreviewPersistenceController.shared.container.viewContext
    let concert = Concert.preview(in: context)

    VStack {
        Button("present") {
            presenting = true
        }
    }
    .sheet(isPresented: $presenting) {
        ConcertEditView(concert: concert, onSave: { _ in })
    }
}
#endif
