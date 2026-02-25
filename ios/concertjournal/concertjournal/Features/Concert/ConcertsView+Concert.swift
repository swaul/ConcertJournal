//
//  ConcertsView+Past.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

extension ConcertsView {

    @ViewBuilder
    func concertsGroupedSection(viewModel: ConcertsViewModel) -> some View {
        if !viewModel.allConcerts.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text(TextKey.pastConcerts.localized)
                    .font(.cjTitle)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ForEach(viewModel.concertsByArtistGrouped) { artistGroup in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Button {
                                navigationManager.push(.artistDetail(artistGroup.artist))
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: artistGroup.artist.imageUrl ?? "")) { result in
                                        switch result {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure:
                                            ZStack {
                                                dependencies.colorThemeManager.appTint.opacity(0.2)
                                                Image(systemName: "music.note")
                                                    .font(.title3)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }
                                        @unknown default:
                                            Color.gray
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(artistGroup.artist.name)
                                            .font(.cjHeadline)

                                        Text("\(artistGroup.concerts.count) Konzerte")
                                            .font(.cjCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Most Recent Date
                            Text(artistGroup.mostRecentDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    GroupedConcerts(artistGroup: artistGroup) { concert in
                        concertToDelete = concert
                    }
                }
                //                    AdaptiveBannerAdView()
                //                        .padding(.horizontal, 20)
            }
        }
    }

}

struct GroupedConcerts: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.navigationManager) var navigationManager

    @State var artistGroup: ArtistGroupedConcerts
    @State var isExpanded: Bool = true

    var selectConcertToDelete: (Concert) -> Void

    var body: some View {
        VStack(spacing: 20) {
            if artistGroup.concerts.contains(where: { $0.tour != nil }) {
                tourGroupedConcerts(artistGroup)
            } else {
                simpleGroupedConcerts(artistGroup)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func simpleGroupedConcerts(_ artistGroup: ArtistGroupedConcerts) -> some View {
        VStack(spacing: 8) {
            ForEach(artistGroup.concertsSorted, id: \.id) { concert in
                ConcertRowInGroup(concert: concert, tour: concert.tour, selectConcertToDelete: selectConcertToDelete)
            }
        }
    }

    @ViewBuilder
    private func tourGroupedConcerts(_ artistGroup: ArtistGroupedConcerts) -> some View {
        ForEach(artistGroup.concertsByTour) { tourGroup in
            TourGroupedConcerts(tourGroup: tourGroup, selectConcertToDelete: selectConcertToDelete)
        }
    }
}

struct TourGroupedConcerts: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.navigationManager) var navigationManager

    let tourGroup: TourGroup
    var selectConcertToDelete: (Concert) -> Void

    @State var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tour Header (wenn nicht "Keine Tour")
            if !tourGroup.hasNoTour {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)

                        Text(tourGroup.tourName)
                            .font(.cjCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)

                        Text("• \(tourGroup.pastConcerts.count + tourGroup.futureConcerts.count)")
                            .font(.cjCaption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: "chevron.up")
                            .rotationEffect(isExpanded ? .zero : .degrees(180))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(dependencies.colorThemeManager.appTint.opacity(0.1))
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }

            if tourGroup.hasNoTour {
                VStack(spacing: 8) {
                    ForEach(tourGroup.futureConcerts + tourGroup.pastConcerts, id: \.id) { concert in
                        ConcertRowInGroup(concert: concert, tour: concert.tour, selectConcertToDelete: selectConcertToDelete)
                    }
                }
            }

            if !tourGroup.hasNoTour, isExpanded == true {
                VStack(alignment: .leading, spacing: 12) {
                    if !tourGroup.futureConcerts.isEmpty {
                        Text("Bevorstehende Konzerte dieser Tour")
                            .font(.cjCaption)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                        VStack(spacing: 8) {
                            ForEach(tourGroup.futureConcerts, id: \.id) { concert in
                                ConcertRowInGroup(concert: concert, tour: concert.tour, selectConcertToDelete: selectConcertToDelete)
                            }
                        }
                        .padding(.leading)
                    }

                    if !tourGroup.pastConcerts.isEmpty {
                        Text("Vergangene Konzerte dieser Tour")
                            .font(.cjCaption)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                        VStack(spacing: 8) {
                            ForEach(tourGroup.pastConcerts, id: \.id) { concert in
                                ConcertRowInGroup(concert: concert, tour: concert.tour, selectConcertToDelete: selectConcertToDelete)
                            }
                        }
                        .padding(.leading)
                    }
                }
                .transition(.push(from: .trailing))
            }
        }
        .padding(8)
        .background(dependencies.colorThemeManager.appTint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ConcertRowInGroup: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.navigationManager) var navigationManager

    let concert: Concert
    let tour: Tour?
    var selectConcertToDelete: (Concert) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = concert.title, !title.isEmpty {
                        Text(title)
                            .font(.cjBody)
                            .fontWeight(.semibold)
                    }

                    HStack(spacing: 8) {
                        if let venue = concert.venue {
                            Label(venue.name, systemImage: "mappin.circle.fill")
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let city = concert.city {
                            Label(city, systemImage: "building.2.fill")
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(concert.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.cjCaption)
                        .foregroundStyle(.secondary)

                    // Rating falls vorhanden
                    let rating = Int(concert.rating)
                    if rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<Int(rating), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }

            // Tour Badge wenn vorhanden
            if let tour = concert.tour {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(tour.name)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(dependencies.colorThemeManager.appTint.opacity(0.15))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .rectangleGlass()
        .onTapGesture {
            HapticManager.shared.impact(.light)
            navigationManager.push(.concertDetail(concert))
        }
        .contentShape(Rectangle())
        .contextMenu {
            if let tour {
                Button {
                    HapticManager.shared.impact(.medium)
                    navigationManager.presentSheet(.tourDetail(tour))
                } label: {
                    Label("Tour anzeigen", systemImage: "tag.fill")
                }
                .font(.cjBody)

                Divider()
            }

            Button {
                HapticManager.shared.impact(.light)
                navigationManager.push(.concertDetail(concert))
            } label: {
                Label(TextKey.detailPage.localized, systemImage: "info.circle")
            }
            .font(.cjBody)

            Divider()

            Button(role: .destructive) {
                HapticManager.shared.impact(.medium)
                selectConcertToDelete(concert)
            } label: {
                Label(TextKey.concertDelete.localized, systemImage: "trash")
            }
            .font(.cjBody)
        }
    }
}
