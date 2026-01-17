//
//  ConcertBackgroundImage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 06.01.26.
//

import SwiftUI

struct ConcertBackgroundImage: View {
    
    let width: CGFloat
    let imageUrl: String
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { result in
            result.image?
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .frame(width: width)
        .overlay {
            LinearGradient(
                colors: [Color.clear, Color.clear, Color.black.opacity(0.15), Color.black.opacity(0.35), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
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
        .frame(width: width)
        .ignoresSafeArea()
    }
}
