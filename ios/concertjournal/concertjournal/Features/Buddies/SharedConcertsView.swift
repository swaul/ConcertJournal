//
//  SharedConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.02.26.
//

import SwiftUI
import CoreData

// MARK: - Shared Concerts Sheet

struct SharedConcertsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let buddy: Buddy

    private var sharedConcerts: [Concert] {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue)
        let all = (try? dependencies.coreData.viewContext.fetch(request)) ?? []
        return all.filter { concert in
            concert.buddiesArray.contains { $0.id == buddy.userId }
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                buddyHeader

                if sharedConcerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Keine gemeinsamen Konzerte")
                            .font(.cjHeadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sharedConcerts) { concert in
                                SharedConcertRow(concert: concert)
                            }
                        }
                        .padding()
                    }
                    .safeAreaPadding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextKey.done.localized) { dismiss() }
                        .font(.cjBody)
                }
            }
        }
    }

    private var buddyHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                AvatarView(url: buddy.avatarURL, name: buddy.displayName, size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(buddy.displayName)
                        .font(.cjTitle2)

                    Label("\(sharedConcerts.count) gemeinsame Konzerte", systemImage: "music.note.list")
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()
        }
        .background(.ultraThinMaterial)
    }
}

private struct SharedConcertRow: View {
    @Environment(\.dependencies) private var dependencies
    let concert: Concert

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                dependencies.colorThemeManager.appTint.opacity(0.3)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(concert.title ?? concert.artist.name)
                    .font(.cjHeadline)
                    .lineLimit(1)

                Text(concert.artist.name)
                    .font(.cjBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(concert.date.shortDateOnlyString)
                        .font(.cjFootnote)
                    if let venue = concert.venue {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(venue.name)
                            .font(.cjFootnote)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if concert.rating > 0 {
                Text("\(concert.rating)/10")
                    .font(.cjFootnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}
