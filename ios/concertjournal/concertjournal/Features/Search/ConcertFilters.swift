//
//  FilterView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Foundation

// MARK: - Filter Enums

enum ConcertSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Neueste zuerst"
    case dateOldest = "Älteste zuerst"
    case artistAZ = "Künstler A-Z"
    case artistZA = "Künstler Z-A"
    case ratingHighest = "Beste Bewertung"
    case ratingLowest = "Schlechteste Bewertung"
    case cityAZ = "Stadt A-Z"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dateNewest, .dateOldest:
            return "calendar"
        case .artistAZ, .artistZA:
            return "music.mic"
        case .ratingHighest, .ratingLowest:
            return "star.fill"
        case .cityAZ:
            return "location.fill"
        }
    }
}

enum DateFilterOption: String, CaseIterable, Identifiable {
    case all = "Alle"
    case thisYear = "Dieses Jahr"
    case lastYear = "Letztes Jahr"
    case last3Months = "Letzte 3 Monate"
    case last6Months = "Letzte 6 Monate"
    case custom = "Benutzerdefiniert"

    var id: String { rawValue }

    var icon: String {
        return "calendar"
    }

    func dateRange() -> (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .all:
            return (nil, nil)
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))
            return (startOfYear, nil)
        case .lastYear:
            let lastYearStart = calendar.date(byAdding: .year, value: -1, to: now)
            let lastYearEnd = calendar.date(from: calendar.dateComponents([.year], from: now))
            return (lastYearStart, lastYearEnd)
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)
            return (threeMonthsAgo, nil)
        case .last6Months:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)
            return (sixMonthsAgo, nil)
        case .custom:
            return (nil, nil)
        }
    }
}

enum RatingFilterOption: Int, CaseIterable, Identifiable {
    case all = 0
    case fiveStars = 5
    case fourPlus = 4
    case threePlus = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "Alle Bewertungen"
        case .fiveStars:
            return "5 Sterne"
        case .fourPlus:
            return "4+ Sterne"
        case .threePlus:
            return "3+ Sterne"
        }
    }

    var icon: String {
        return "star.fill"
    }
}

// MARK: - Filter State

@Observable
class ConcertFilters {

    // MARK: - Properties

    var sortOption: ConcertSortOption = .dateNewest
    var dateFilter: DateFilterOption = .all
    var customDateRange: (start: Date?, end: Date?) = (nil, nil)
    var ratingFilter: RatingFilterOption = .all
    var selectedArtists: Set<String> = []
    var selectedCities: Set<String> = []
    var searchQuery: String = ""

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        dateFilter != .all ||
        ratingFilter != .all ||
        !selectedArtists.isEmpty ||
        !selectedCities.isEmpty ||
        !searchQuery.isEmpty ||
        (dateFilter == .custom && (customDateRange.start != nil || customDateRange.end != nil))
    }

    var activeFilterCount: Int {
        var count = 0
        if dateFilter != .all { count += 1 }
        if ratingFilter != .all { count += 1 }
        if !selectedArtists.isEmpty { count += selectedArtists.count }
        if !selectedCities.isEmpty { count += selectedCities.count }
        if !searchQuery.isEmpty { count += 1 }
        return count
    }

    var activeFilterChips: [FilterChip] {
        var chips: [FilterChip] = []

        // Sort option (always shown, not removable)
        chips.append(FilterChip(
            id: "sort",
            title: sortOption.rawValue,
            icon: sortOption.icon,
            isRemovable: false,
            type: .sort
        ))

        // Date filter
        if dateFilter != .all {
            let title = dateFilter == .custom
            ? customDateRangeString
            : dateFilter.rawValue
            chips.append(FilterChip(
                id: "date",
                title: title,
                icon: "calendar",
                isRemovable: true,
                type: .date
            ))
        }

        // Rating filter
        if ratingFilter != .all {
            chips.append(FilterChip(
                id: "rating",
                title: ratingFilter.displayName,
                icon: "star.fill",
                isRemovable: true,
                type: .rating
            ))
        }

        // Artist filters
        for artist in selectedArtists {
            chips.append(FilterChip(
                id: "artist-\(artist)",
                title: artist,
                icon: "music.mic",
                isRemovable: true,
                type: .artist(artist)
            ))
        }

        // City filters
        for city in selectedCities {
            chips.append(FilterChip(
                id: "city-\(city)",
                title: city,
                icon: "location.fill",
                isRemovable: true,
                type: .city(city)
            ))
        }

        // Search query
        if !searchQuery.isEmpty {
            chips.append(FilterChip(
                id: "search",
                title: "Suche: \(searchQuery)",
                icon: "magnifyingglass",
                isRemovable: true,
                type: .search
            ))
        }

        return chips
    }

    private var customDateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = customDateRange.start, let end = customDateRange.end {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = customDateRange.start {
            return "Ab \(formatter.string(from: start))"
        } else if let end = customDateRange.end {
            return "Bis \(formatter.string(from: end))"
        } else {
            return "Datum wählen"
        }
    }

    // MARK: - Methods

    func reset() {
        sortOption = .dateNewest
        dateFilter = .all
        customDateRange = (nil, nil)
        ratingFilter = .all
        selectedArtists.removeAll()
        selectedCities.removeAll()
        searchQuery = ""
    }

    func removeFilter(_ chip: FilterChip) {
        switch chip.type {
        case .sort:
            break // Can't remove sort
        case .date:
            dateFilter = .all
            customDateRange = (nil, nil)
        case .rating:
            ratingFilter = .all
        case .artist(let artist):
            selectedArtists.remove(artist)
        case .city(let city):
            selectedCities.remove(city)
        case .search:
            searchQuery = ""
        }
    }

    func toggleArtist(_ artist: String) {
        if selectedArtists.contains(artist) {
            selectedArtists.remove(artist)
        } else {
            selectedArtists.insert(artist)
        }
    }

    func toggleCity(_ city: String) {
        if selectedCities.contains(city) {
            selectedCities.remove(city)
        } else {
            selectedCities.insert(city)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isRemovable: Bool
    let type: FilterType

    enum FilterType: Equatable {
        case sort
        case date
        case rating
        case artist(String)
        case city(String)
        case search
    }
}

// MARK: - Filter Logic Extensions

extension ConcertFilters {

    /// Applies all filters to a list of concerts
    func apply(to concerts: [FullConcertVisit]) -> [FullConcertVisit] {
        var filtered = concerts

        // Apply search query
        if !searchQuery.isEmpty {
            filtered = filtered.filter { concert in
                concert.artist.name.localizedCaseInsensitiveContains(searchQuery) ||
                concert.venue?.name.localizedCaseInsensitiveContains(searchQuery) == true ||
                concert.city?.localizedCaseInsensitiveContains(searchQuery) == true ||
                concert.title?.localizedCaseInsensitiveContains(searchQuery) == true
            }
        }

        // Apply date filter
        let dateRange = dateFilter == .custom ? customDateRange : dateFilter.dateRange()
        if let start = dateRange.start {
            filtered = filtered.filter { $0.date >= start }
        }
        if let end = dateRange.end {
            filtered = filtered.filter { $0.date <= end }
        }

        // Apply rating filter
        if ratingFilter != .all {
            filtered = filtered.filter { concert in
                guard let rating = concert.rating else { return false }
                return rating >= ratingFilter.rawValue
            }
        }

        // Apply artist filter
        if !selectedArtists.isEmpty {
            filtered = filtered.filter { concert in
                selectedArtists.contains(concert.artist.name)
            }
        }

        // Apply city filter
        if !selectedCities.isEmpty {
            filtered = filtered.filter { concert in
                guard let city = concert.city else { return false }
                return selectedCities.contains(city)
            }
        }

        // Apply sorting
        return sort(concerts: filtered)
    }

    /// Sorts concerts based on current sort option
    private func sort(concerts: [FullConcertVisit]) -> [FullConcertVisit] {
        switch sortOption {
        case .dateNewest:
            return concerts.sorted { $0.date > $1.date }
        case .dateOldest:
            return concerts.sorted { $0.date < $1.date }
        case .artistAZ:
            return concerts.sorted { $0.artist.name < $1.artist.name }
        case .artistZA:
            return concerts.sorted { $0.artist.name > $1.artist.name }
        case .ratingHighest:
            return concerts.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .ratingLowest:
            return concerts.sorted { ($0.rating ?? 0) < ($1.rating ?? 0) }
        case .cityAZ:
            return concerts.sorted { ($0.city ?? "") < ($1.city ?? "") }
        }
    }

    /// Extracts unique artists from concerts
    func getAvailableArtists(from concerts: [FullConcertVisit]) -> [String] {
        let artists = Set(concerts.map { $0.artist.name })
        return artists.sorted()
    }

    /// Extracts unique cities from concerts
    func getAvailableCities(from concerts: [FullConcertVisit]) -> [String] {
        let cities = Set(concerts.compactMap { $0.city })
        return cities.sorted()
    }
}
