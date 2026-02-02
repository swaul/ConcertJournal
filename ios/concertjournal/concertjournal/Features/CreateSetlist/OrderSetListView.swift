//
//  OrderSetListView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import SwiftUI

public struct OrderSetListView: View {

    @State var viewModel: CreateSetlistViewModel

    public var body: some View {
        VStack {
            List {
                ForEach(viewModel.selectedSongs.enumerated(), id: \.element.id) { index, song in
                    makeOrderSongView(index: index, song: song)
                }
                .onMove { indexSet, offset in
                    viewModel.selectedSongs.move(fromOffsets: indexSet, toOffset: offset)
                }
                .onDelete { indexSet in
                    viewModel.selectedSongs.remove(atOffsets: indexSet)
                }
            }
        }
        .navigationTitle("Reihenfolge anpassen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.saveSetlist()
                } label: {
                    Text("Next")
                        .font(.cjBody)
                }
            }
        }
    }

    @ViewBuilder
    func makeOrderSongView(index: Int, song: SpotifySong) -> some View {
        Grid {
            GridRow {
                Text("\(index + 1).")
                    .font(.cjTitle2)
                    .frame(width: 28)
                Text(song.name)
                    .font(.cjHeadline)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "line.3.horizontal")
                    .frame(width: 28)
            }
            if let artistsString = song.artists?.compactMap({ $0.name }).joined(separator: ", ") {
                GridRow {
                    Rectangle().fill(.clear)
                        .frame(width: 28)

                    Text(artistsString)
                        .font(.cjBody)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle().fill(.clear)
                        .frame(width: 28)

                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
