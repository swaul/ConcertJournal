//
//  ArtistDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI

struct ArtistDetailView: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State var viewModel: ArtistDetailViewModel?

    @State var showShouldAddMoreInfo: ShouldAddMoreInfoItem? = nil

    let artist: Artist

    init(artist: Artist) {
        self.artist = artist
    }

    var isLandscape: Bool {
        verticalSizeClass != .regular
    }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            if !isLandscape {
                AsyncImage(url: URL(string: artist.imageUrl ?? "")) { result in
                    result.image?
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: .infinity)
                        .background { Color.black }
                        .ignoresSafeArea()
                        .blur(radius: 10)
                        .opacity(0.8)
                }
            }

            VStack {
                if let viewModel, !viewModel.artistInfos.isEmpty {
                    ScrollView {
                        ForEach(viewModel.artistInfos, id: \.year) { info in
                            makeArtistInfoGrid(for: info)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    LoadingView()
                }
            }
            .frame(maxWidth: isLandscape ? .infinity : UIScreen.screenWidth)
        }
        .navigationTitle(artist.name)
        .task {
            guard viewModel == nil else { return }
            viewModel = ArtistDetailViewModel(artist: artist, repository: dependencies.offlineConcertRepository)
        }
        .adaptiveSheet(item: $showShouldAddMoreInfo) { item in
            ShouldAddMoreInfoView(item: item)
        }
    }

    @ViewBuilder
    func makeArtistInfoGrid(for artistInfo: ArtistInfo) -> some View {
        VStack {
            Text(artistInfo.year)
                .font(.cjTitleF)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack {
                HStack {
                    Text(TextKey.artistDetailConcertsThisYear.localized)
                        .font(.cjBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(artistInfo.totalPastConcerts))
                        .font(.cjTitle)
                }
                if artistInfo.futureConcerts != 0 {
                    HStack {
                        Text(TextKey.artistDetailPlannedThisYear.localized)
                            .font(.cjBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(artistInfo.futureConcerts))
                            .font(.cjTitle)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                }
                if artistInfo.hasAnyTravelInfos {
                    HStack {
                        Text(TextKey.artistDetailTravelSummary.localized)
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let moneySpentOnTravel = artistInfo.moneySpentOnTravel {
                        HStack {
                            Text(TextKey.artistDetailTravelExpenses.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnTravel.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let moneySpentOnHotels = artistInfo.moneySpentOnHotels {
                        HStack {
                            Text(TextKey.artistDetailTravelSpentHotels.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnHotels.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDistance = artistInfo.travelDistance {
                        HStack {
                            Text(TextKey.artistDetailTravelTotal.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DistanceParser.format(travelDistance))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDuration = artistInfo.travelDuration {
                        HStack {
                            Text(TextKey.artistDetailTravelTime.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DurationParser.format(travelDuration))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let waitedFor = artistInfo.waitedFor {
                        HStack {
                            Text(TextKey.artistDetailTravelWaiting.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DurationParser.format(waitedFor))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                }
                if artistInfo.hasAnyTicketInfos {
                    HStack {
                        Text(TextKey.artistDetailTicketsSummary.localized)
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let ticketCategories = artistInfo.ticketCategories {
                        HStack {
                            Text(TextKey.artistDetailTicketCategories.localized)
                                .font(.cjBody)
                                .padding(.top, 2)
                        }
                        ForEach(ticketCategories.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { category in
                            let ticketCategory: TicketCategory = category.key
                            let count: Int = category.value

                            Text("\(count)x \(ticketCategory.label)")
                                .font(.cjTitle)
                                .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background {
                                ticketCategory.color
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    if let ticketTypes = artistInfo.ticketTypes {
                        HStack {
                            Text(TextKey.artistDetailTicketTypes.localized)
                                .font(.cjBody)
                                .padding(.top, 2)
                        }
                        ForEach(ticketTypes.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.value) { category in
                            let ticketType: TicketType = category.key
                            let count: Int = category.value

                            HStack {
                                // TODO: LOCALIZATION
                                Text("\(ticketType.label) Tickets")
                                    .font(.cjBody)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(count))
                                    .font(.cjTitle)
                                    .frame(alignment: .trailing)
                            }
                        }
                    }
                    if let moneySpentOnTickets = artistInfo.moneySpentOnTickets {
                        HStack {
                            Text(TextKey.artistDetailTravelSpentTickets.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnTickets.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                }
                if let moneySpent = artistInfo.moneySpentTotal {
                    HStack {
                        Text(TextKey.artistDetailTravelSpentTotal.localized)
                            .font(.cjBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(moneySpent.formatted)
                            .font(.cjTitle)
                            .frame(alignment: .trailing)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                    .padding(.top, 8)
                }

                if let showShouldAddInfoLabel = artistInfo.showShouldAddInfoLabel {
                    HStack {
                        Spacer()
                        Text(TextKey.artistDetailMissingInfos.localized)
                            .font(.cjFootnote)
                            .foregroundStyle(.secondary)
                        Button {
                            showShouldAddMoreInfo = ShouldAddMoreInfoItem(id: UUID(), count: showShouldAddInfoLabel, year: artistInfo.year)
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.cjFootnote)
                        }
                    }
                    .padding(.top, 4)
                }

            }
            .padding()
            .rectangleGlass()
        }
        .padding()
    }
}

extension UIScreen{
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
}

struct ShouldAddMoreInfoItem: Identifiable {
    let id: UUID
    let count: Int
    let year: String

    var text: String {
        TextKey.artistDetailAddInfo.localized(with: String(count), year)
    }
}

struct ShouldAddMoreInfoView: View {

    @Environment(\.dismiss) var dismiss

    let item: ShouldAddMoreInfoItem

    var body: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(TextKey.genericOk.localized)
                        .font(.cjBody)
                }
                .buttonStyle(.glass)
            }
            Text(item.text)
                .font(.cjHeadline)
                .padding(.bottom, 24)
                .lineLimit(nil)
        }
        .padding()
        .frame(minHeight: 200)
    }
}
