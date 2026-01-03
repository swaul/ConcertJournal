//
//  ConcertDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 01.01.26.
//

import Combine
import SwiftUI

class ConcertDetailViewModel: ObservableObject {
    
    let concert: FullConcertVisit
    let artist: Artist
    
    init(concert: FullConcertVisit) {
        self.concert = concert
        self.artist = concert.artist
    }
}

struct ConcertDetailView: View {
    
    @StateObject var viewModel: ConcertDetailViewModel
    
    init(concert: FullConcertVisit) {
        self._viewModel = StateObject(wrappedValue: ConcertDetailViewModel(concert: concert))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ZStack {
                    Group {
                        if let url = viewModel.artist.imageUrl {
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
                    // Fade overlay at the bottom (transparent to match background)
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
                        Text(viewModel.artist.name)
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
    }
}

