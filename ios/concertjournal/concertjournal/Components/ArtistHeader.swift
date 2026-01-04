//
//  ArtistHeader.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import SwiftUI

struct ArtistHeader: View {
    
    let artist: Artist
    
    var body: some View {
        ZStack {
            Group {
                if let url = artist.imageUrl {
                    AsyncImage(url: URL(string: url)) { result in
                        result.image?
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .frame(maxWidth: .infinity)
                            .background { Color.gray }
                        Image(systemName: "note")
                            .frame(width: 32)
                            .foregroundStyle(.white)
                    }
                }
            }
            LinearGradient(
                colors: [Color.clear, Color.clear, Color.black.opacity(0.15), Color.black.opacity(0.35), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
        .frame(maxWidth: .infinity)
        .overlay {
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Text(artist.name)
                    .bold()
                    .font(.system(size: 40))
                    .padding()
                    .glassEffect()

            }
            .padding(.vertical)
            .padding(.trailing)
        }
    }
}
