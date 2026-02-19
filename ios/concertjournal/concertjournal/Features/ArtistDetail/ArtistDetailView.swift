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
    }

    @ViewBuilder
    func makeArtistInfoGrid(for artistInfo: ArtistInfo) -> some View {
        VStack {
            Text(artistInfo.year)
                .font(.cjTitleF)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack {
                HStack {
                    Text("Konzerte in diesem Jahr:")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(artistInfo.totalPastConcerts))
                        .font(.cjTitle)
                }
                if artistInfo.futureConcerts != 0 {
                    HStack {
                        Text("Geplante Konzerte dieses Jahr:")
                            .font(.cjBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(artistInfo.futureConcerts))
                            .font(.cjTitle)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                }
                if artistInfo.hasAnyTravelInfos {
                    HStack {
                        Text("Deine Reisen zusammengefasst:")
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let moneySpentOnTravel = artistInfo.moneySpentOnTravel {
                        HStack {
                            Text("Ausgegeben für Reisen:")
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnTravel.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let moneySpentOnHotels = artistInfo.moneySpentOnHotels {
                        HStack {
                            Text("Ausgegeben für Hotels:")
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(moneySpentOnHotels.formatted)
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDistance = artistInfo.travelDistance {
                        HStack {
                            Text("Insgesamte Strecke:")
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DistanceParser.format(travelDistance))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let travelDuration = artistInfo.travelDuration {
                        HStack {
                            Text("Insgesamte Zeit:")
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DurationParser.format(travelDuration))
                                .font(.cjTitle)
                                .frame(alignment: .trailing)
                        }
                    }
                    if let waitedFor = artistInfo.waitedFor {
                        HStack {
                            Text("Wartezeit:")
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
                        Text("Deine Tickets zusammengefasst:")
                            .font(.cjBody)
                    }
                    .padding(.top, 8)

                    if let ticketCategories = artistInfo.ticketCategories {
                        HStack {
                            Text("Ticket Kategorien")
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
                            Text("Ticket Arten")
                                .font(.cjBody)
                                .padding(.top, 2)
                        }
                        ForEach(ticketTypes.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.value) { category in
                            let ticketType: TicketType = category.key
                            let count: Int = category.value

                            HStack {
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
                            Text("Ausgegeben für Tickets:")
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
                        Text("Insgesamt ausgegeben:")
                            .font(.cjBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(moneySpent.formatted)
                            .font(.cjTitle)
                            .frame(alignment: .trailing)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                    .padding(.top, 8)
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
