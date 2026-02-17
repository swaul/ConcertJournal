//
//  ConcertsView+Past.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

struct PastConcertView: View {
    @Environment(\.dependencies) private var dependencies

    let concert: Concert

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                switch result {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        dependencies.colorThemeManager.appTint.opacity(0.3)
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(concert.artist.name)
                    .font(.cjTitle2)
                    .foregroundStyle(.primary)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let venue = concert.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                        Text(venue.name)
                            .font(.cjBody)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                if let city = concert.city {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption)
                        Text(city)
                            .font(.cjBody)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}
