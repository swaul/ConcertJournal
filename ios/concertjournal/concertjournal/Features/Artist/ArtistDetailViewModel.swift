//
//  ArtistDetailViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 13.02.26.
//

import SwiftUI

@Observable
class ArtistDetailViewModel {

    var isLoading: Bool = true
    let artist: Artist
    let concertRepository: ConcertRepositoryProtocol
    var artistInfos: [ArtistInfo] = []

    init(artist: Artist, concertRepository: ConcertRepositoryProtocol) {
        self.artist = artist
        self.concertRepository = concertRepository

        Task {
            try await collectArtistInfo()
        }
    }

    func collectArtistInfo() async throws {
        isLoading = true
        let concerts = try await concertRepository.fetchConcertsWithArtist(artistId: artist.id)

        let concertsByYear = Dictionary(grouping: concerts, by: { $0.date.year })

        var artistInfos = [ArtistInfo]()
        for year in concertsByYear.keys {
            artistInfos.append(getArtistInfoByYear(concerts: concertsByYear[year] ?? [], year: year))
        }

        artistInfos.sort(by: { $0.year > $1.year })

        isLoading = false
        for (index, artistInfo) in artistInfos.enumerated() {
            withAnimation(.easeInOut(duration: 0.8).delay(0.8 + Double(index))) {
                self.artistInfos.append(artistInfo)
            }
        }
    }

    func getArtistInfoByYear(concerts: [ConcertDetails], year: String) -> ArtistInfo{
        var futureConcertsThisYear = concerts.filter { $0.date > Date.now }.count

        var artistInfo = ArtistInfo(year: year, totalPastConcerts: concerts.count, futureConcerts: futureConcertsThisYear)
        let currency: String = concerts.compactMap { $0.travelExpenses?.currency ?? $0.hotelExpenses?.currency }.first ?? "EUR"

        getTravelInfos(artistInfo: &artistInfo, concerts: concerts, currency: currency)
        getTicketInfos(artistInfo: &artistInfo, concerts: concerts, currency: currency)

        let totalMoneySpent = ((artistInfo.moneySpentOnTravel?.value ?? 0.0)
        + (artistInfo.moneySpentOnHotels?.value ?? 0.0))
        + (artistInfo.moneySpentOnTickets?.value ?? 0.0)

        if totalMoneySpent != 0 {
            artistInfo.moneySpentTotal = Price(value: totalMoneySpent, currency: currency)
        }

        return artistInfo
    }

    func getTravelInfos(artistInfo: inout ArtistInfo, concerts: [ConcertDetails], currency: String) {
        let hotelExpensesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.hotelExpenses?.value ?? 0.0
        }
        let travelExpensesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travelExpenses?.value ?? 0.0
        }

        let traveledDistance = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travelDistance ?? 0.0
        }

        let traveledDuration = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travelDuration ?? 0.0
        }

        if travelExpensesValue != 0 {
            artistInfo.moneySpentOnTravel = Price(value: travelExpensesValue, currency: currency)
        }

        if hotelExpensesValue != 0 {
            artistInfo.moneySpentOnHotels = Price(value: hotelExpensesValue, currency: currency)
        }

        if traveledDistance != 0 {
            artistInfo.travelDistance = traveledDistance
        }

        if traveledDuration != 0 {
            artistInfo.travelDuration = traveledDuration
        }
    }

    func getTicketInfos(artistInfo: inout ArtistInfo, concerts: [ConcertDetails], currency: String) {
        let ticketTypes = concerts.compactMap { $0.ticketType }
        if !ticketTypes.isEmpty {
            artistInfo.ticketTypes = Dictionary(grouping: ticketTypes, by: { $0 })
                .mapValues { $0.count }
        }

        let ticketCategories = concerts.compactMap { $0.ticketCategory }
        if !ticketTypes.isEmpty {
            artistInfo.ticketCategories = Dictionary(grouping: ticketCategories, by: { $0 })
                .mapValues { $0.count }
        }

        let ticketExpenesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.ticketPrice?.value ?? 0.0
        }

        if ticketExpenesValue != 0 {
            artistInfo.moneySpentOnTickets = Price(value: ticketExpenesValue, currency: currency)
        }
    }
}

struct ArtistInfo {
    let year: String
    let totalPastConcerts: Int
    let futureConcerts: Int
    var moneySpentTotal: Price?

    // Travel
    var moneySpentOnHotels: Price?
    var moneySpentOnTravel: Price?
    var travelDistance: Double?
    var travelDuration: Double?

    // Ticket
    var moneySpentOnTickets: Price?
    var ticketCategories: [TicketCategory: Int]?
    var ticketTypes: [TicketType: Int]?

    var hasAnyTravelInfos: Bool {
        moneySpentOnHotels != nil || moneySpentOnTravel != nil || travelDistance != nil || travelDuration != nil
    }

    var hasAnyTicketInfos: Bool {
        moneySpentOnTickets != nil || ticketCategories != nil || ticketTypes != nil

    }
}

extension Date {
    var year: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        guard let year = components.year else { return String("NOYEAR") }
        return String(year)
    }
}
