//
//  ArtistDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI

struct ArtistDetailView: View {

    let artist: Artist

    var body: some View {
        Text(artist.name)
    }
}
