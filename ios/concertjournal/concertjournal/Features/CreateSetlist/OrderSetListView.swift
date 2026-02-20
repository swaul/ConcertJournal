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
                    Text(TextKey.nextStep.localized)
                        .font(.cjBody)
                }
            }
        }
    }

    @ViewBuilder
    func makeOrderSongView(index: Int, song: SetlistSong) -> some View {
        HStack {
            Grid(verticalSpacing: 8) {
                GridRow {
                    Text("\(index + 1).")
                        .font(.cjTitle2)
                        .frame(width: 28)
                    Text(song.name)
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
            Image(systemName: "line.3.horizontal")
                .frame(width: 28)
        }
    }
}
