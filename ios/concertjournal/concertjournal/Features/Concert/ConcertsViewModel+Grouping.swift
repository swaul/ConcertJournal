//
//  ArtistGroupedConcerts.swift
//  concertjournal
//
//  Created by Paul Kühnel on 25.02.26.
//

import Foundation

// MARK: - Helper Models für Grouping

struct ArtistGroupedConcerts: Identifiable {
    let id = UUID().uuidString
    let artist: Artist
    let concerts: [Concert]
    let mostRecentDate: Date

    var concertsByTour: [TourGroup] {
        var tourGroups: [String: [Concert]] = [:]
        var tourNames: [String: String] = [:]

        for concert in concerts {
            // Falls Concert zu Tour gehört
            if let tour = concert.tour {
                let tourKey = tour.id.uuidString
                tourNames[tourKey] = tour.name
                tourGroups[tourKey, default: []].append(concert)
            } else {
                tourGroups["_no_tour_", default: []].append(concert)
            }
        }

        return tourGroups.map { key, concertsInTour in
            let tourName = tourNames[key] ?? "Keine Tour"
            let mostRecentDate = concertsInTour.max(by: { $0.date < $1.date })?.date ?? Date()

            return TourGroup(
                tourId: key == "_no_tour_" ? nil : key,
                tourName: tourName,
                futureConcerts: concertsInTour.filter { $0.date > Date.now },
                pastConcerts: concertsInTour.filter { $0.date <= Date.now },
                mostRecentDate: mostRecentDate,
                hasNoTour: key == "_no_tour_"
            )
        }
        .sorted { $0.mostRecentDate > $1.mostRecentDate }
    }

    var concertsSorted: [Concert] {
        concerts.sorted { $0.date > $1.date }
    }
}

struct TourGroup: Identifiable {
    let id = UUID().uuidString
    let tourId: String?
    let tourName: String
    let futureConcerts: [Concert]
    let pastConcerts: [Concert]
    let mostRecentDate: Date
    let hasNoTour: Bool
}

// MARK: - Extension für ConcertsViewModel

extension ConcertsViewModel {

    var concertsByArtistGrouped: [ArtistGroupedConcerts] {
        var artistGroups: [String: [Concert]] = [:]

        for concert in allConcerts {
            let artistKey = concert.artist.id.uuidString
            artistGroups[artistKey, default: []].append(concert)
        }

        let grouped = artistGroups.map { _, concerts in
            let artist = concerts.first!.artist
            let mostRecentDate = concerts.max(by: { $0.date < $1.date })?.date ?? Date()

            return ArtistGroupedConcerts(
                artist: artist,
                concerts: concerts,
                mostRecentDate: mostRecentDate
            )
        }

        return grouped.sorted { $0.mostRecentDate > $1.mostRecentDate }
    }
}
