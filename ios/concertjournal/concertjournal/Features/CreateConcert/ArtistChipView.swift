//
//  ArtistChipView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

protocol ArtistChip {
    var imageUrl: String? { get }
    var name: String { get }
}

extension Artist: ArtistChip { }
extension ArtistDTO: ArtistChip { }

struct ArtistChipView: View {

    @Environment(\.dependencies) private var dependencies

    let artist: any ArtistChip
    let removeable: Bool

    let onRemove: () -> Void

    var body: some View {
        VStack {
            AsyncImage(url: URL(string: artist.imageUrl ?? "")) { result in
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
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)

            HStack(spacing: 6) {
                Text(artist.name)
                    .font(.cjHeadline)
                    .lineLimit(1)

                if removeable {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(dependencies.colorThemeManager.appTint.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(dependencies.colorThemeManager.appTint.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
