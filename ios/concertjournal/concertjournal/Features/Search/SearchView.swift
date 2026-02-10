//
//  Search.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import Foundation

struct SearchView: View {

    @Environment(\.dependencies) private var dependencies

    @Bindable var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(viewModel.concertsToDisaplay, id: \.id) { concert in
                        visitItem(visit: concert)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .searchable(text: $viewModel.searchText)
            .task {
                do {
                    try await viewModel.loadConcerts()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    func visitItem(visit: FullConcertVisit) -> some View {
        HStack(spacing: 0) {
            Group {
                AsyncImage(url: URL(string: visit.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        Color.gray
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        dependencies.colorThemeManager.appTint
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading) {
                MarqueeText(visit.artist.name, font: .cjTitle)
                    .foregroundStyle(.white)
                    .frame(height: 30)
                if let venue = visit.venue {
                    Text(venue.name)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
                if let city = visit.city {
                    Text(city)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
            }
            Spacer()
        }
        .compositingGroup()
        .background {
            dependencies.colorThemeManager.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 100)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: UIColor.systemBackground))
                .shadow(radius: 3, x: 2, y: 2)
        }
    }
}
