//
//  ArtistDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI

struct ArtistDetailView: View {

    @Environment(\.dependencies) var dependencies

    @State var viewModel: ArtistDetailViewModel?

    @State var showShouldAddMoreInfo: ShouldAddMoreInfoItem? = nil

    let artist: Artist

    init(artist: Artist) {
        self.artist = artist
    }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

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
            .frame(width: UIScreen.screenWidth)
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
                    Text(TextKey.concertsThisYear.localized)
                        .font(.cjBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(artistInfo.totalPastConcerts))
                        .font(.cjTitle)
                }
                if artistInfo.futureConcerts != 0 {
                    HStack {
                        Text(TextKey.plannedThisYear.localized)
                            .font(.cjBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(artistInfo.futureConcerts))
                            .font(.cjTitle)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                }
                if artistInfo.hasAnyTravelInfos {
                    HStack {
                        Text(TextKey.summary.localized)
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let moneySpentOnTravel = artistInfo.moneySpentOnTravel {
                        HStack {
                            Text(TextKey.spentTotal.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnTravel.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let moneySpentOnHotels = artistInfo.moneySpentOnHotels {
                        HStack {
                            Text(TextKey.spentHotels.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnHotels.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDistance = artistInfo.travelDistance {
                        HStack {
                            Text(TextKey.total.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DistanceParser.format(travelDistance))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDuration = artistInfo.travelDuration {
                        HStack {
                            Text(TextKey.totalTime.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DurationParser.format(travelDuration))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let waitedFor = artistInfo.waitedFor {
                        HStack {
                            Text(TextKey.waiting.localized)
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
                        Text(TextKey.ticketsSummary.localized)
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let ticketCategories = artistInfo.ticketCategories {
                        HStack {
                            Text(TextKey.categories.localized)
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
                            Text(TextKey.types.localized)
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
                            Text(TextKey.spentTickets.localized)
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
                        Text(TextKey.spentTotal.localized)
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
                        Text("Fehlen hier infos?")
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
}

struct ShouldAddMoreInfoItem: Identifiable {
    let id: UUID
    let count: Int
    let year: String

    var text: String {
        "Du hast \(count) Konzerte im Jahr \(year) ohne info über dein Ticket oder deine Reise. Füge mehr infos hinzu, um hier eine bessere übersicht zu haben"
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
                    Text("Fertig")
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
