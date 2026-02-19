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
    let repository: OfflineConcertRepositoryProtocol
    var artistInfos: [ArtistInfo] = []

    init(artist: Artist, repository: OfflineConcertRepositoryProtocol) {
        self.artist = artist
        self.repository = repository

        collectArtistInfo()
    }

    func collectArtistInfo() {
        isLoading = true
        let concerts = repository.fetchConcertsWithArtist(artist.id)

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

    func getArtistInfoByYear(concerts: [Concert], year: String) -> ArtistInfo{
        var futureConcertsThisYear = concerts.filter { $0.date > Date.now }.count

        var artistInfo = ArtistInfo(year: year, totalPastConcerts: concerts.count, futureConcerts: futureConcertsThisYear)
        let currency: String = concerts.compactMap { $0.travel?.travelExpenses?.currency ?? $0.travel?.hotelExpenses?.currency }.first ?? "EUR"

        getTravelInfos(artistInfo: &artistInfo, concerts: concerts, currency: currency)
        getTicketInfos(artistInfo: &artistInfo, concerts: concerts, currency: currency)

        let totalMoneySpent = ((artistInfo.moneySpentOnTravel?.value ?? 0.0)
        + (artistInfo.moneySpentOnHotels?.value ?? 0.0))
        + (artistInfo.moneySpentOnTickets?.value ?? 0.0)

        if totalMoneySpent != 0 {
            artistInfo.moneySpentTotal = PriceDTO(value: totalMoneySpent, currency: currency)
        }

        return artistInfo
    }

    func getTravelInfos(artistInfo: inout ArtistInfo, concerts: [Concert], currency: String) {
        let hotelExpensesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travel?.hotelExpenses?.value ?? 0.0
        }

        let travelExpensesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travel?.travelExpenses?.value ?? 0.0
        }

        let traveledDistance = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travel?.travelDistance ?? 0.0
        }

        let traveledDuration = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.travel?.travelDuration ?? 0.0
        }

        if travelExpensesValue != 0 {
            artistInfo.moneySpentOnTravel = PriceDTO(value: Decimal(travelExpensesValue), currency: currency)
        }

        if hotelExpensesValue != 0 {
            artistInfo.moneySpentOnHotels = PriceDTO(value: Decimal(hotelExpensesValue), currency: currency)
        }

        if traveledDistance != 0 {
            artistInfo.travelDistance = traveledDistance
        }

        if traveledDuration != 0 {
            artistInfo.travelDuration = traveledDuration
        }

        let waitingTime = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += getWaitingTime(for: detail) ?? 0.0
        }

        if waitingTime != 0 {
            artistInfo.waitedFor = waitingTime
        }
    }

    func getWaitingTime(for concert: Concert) -> Double? {
        guard let openingTime = concert.openingTime, let arrivedAt = concert.travel?.arrivedAt else { return nil }
        let waitingTime = openingTime.timeIntervalSince(arrivedAt)
        return waitingTime
    }

    func getTicketInfos(artistInfo: inout ArtistInfo, concerts: [Concert], currency: String) {
        let ticketTypes = concerts.compactMap { $0.ticket?.ticketTypeEnum }
        if !ticketTypes.isEmpty {
            artistInfo.ticketTypes = Dictionary(grouping: ticketTypes, by: { $0 })
                .mapValues { $0.count }
        }

        let ticketCategories = concerts.compactMap { $0.ticket?.ticketCategoryEnum }
        if !ticketTypes.isEmpty {
            artistInfo.ticketCategories = Dictionary(grouping: ticketCategories, by: { $0 })
                .mapValues { $0.count }
        }

        let ticketExpenesValue = concerts.reduce(into: 0.0) { partialResult, detail in
            partialResult += detail.ticket?.ticketPrice?.value ?? 0.0
        }

        if ticketExpenesValue != 0 {
            artistInfo.moneySpentOnTickets = PriceDTO(value: Decimal(ticketExpenesValue), currency: currency)
        }
    }
}

struct ArtistInfo {
    let year: String
    let totalPastConcerts: Int
    let futureConcerts: Int
    var moneySpentTotal: PriceDTO?

    // Travel
    var moneySpentOnHotels: PriceDTO?
    var moneySpentOnTravel: PriceDTO?
    var travelDistance: Double?
    var travelDuration: Double?
    var waitedFor: Double?

    // Ticket
    var moneySpentOnTickets: PriceDTO?
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
