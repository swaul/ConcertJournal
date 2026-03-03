//
//  ConcertsView+FutureConcert.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

struct FutureConcertView: View {
    @Environment(\.dependencies) private var dependencies

    let concert: Concert

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay
            ZStack(alignment: .bottomLeading) {
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
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(width: 280, height: 180)
                .clipped()

                // Date Badge
                Text(concert.date.dateOnlyString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(12)
            }

            // Info Section
            VStack(alignment: .leading, spacing: 8) {
                Text(concert.artist.name)
                    .font(.cjTitle2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let venue = concert.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(venue.name)
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text("")
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(0)
                }

                if let city = concert.city {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.caption)
                        Text(city)
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text("")
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
