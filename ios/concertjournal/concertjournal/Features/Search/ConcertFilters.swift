//
//  FilterView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Foundation

// MARK: - Filter Enums

enum ConcertSortOption: String, CaseIterable, Identifiable {
    case dateNewest
    case dateOldest
    case artistAZ
    case artistZA
    case ratingHighest
    case ratingLowest
    case cityAZ

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateNewest:
            TextKey.searchSortorderDateNewest.localized
        case .dateOldest:
            TextKey.searchSortorderDateOldest.localized
        case .artistAZ:
            TextKey.searchSortorderArtistAz.localized
        case .artistZA:
            TextKey.searchSortorderArtistZa.localized
        case .ratingHighest:
            TextKey.searchSortorderRatingHighest.localized
        case .ratingLowest:
            TextKey.searchSortorderRatingLowest.localized
        case .cityAZ:
            TextKey.searchSortorderCityAz.localized
        }
    }
    
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
    case all
    case thisYear
    case lastYear
    case last3Months
    case last6Months
    case custom

    var id: String { rawValue }

    var icon: String {
        return "calendar"
    }
    
    var label: String {
        switch self {
        case .all:
            TextKey.searchFilterDateAll.localized
        case .thisYear:
            TextKey.searchFilterDateThisYear.localized
        case .lastYear:
            TextKey.searchFilterDateLastYear.localized
        case .last3Months:
            TextKey.searchFilterDateLast3Months.localized
        case .last6Months:
            TextKey.searchFilterDateLast6Months.localized
        case .custom:
            TextKey.searchFilterDateCustom.localized
        }
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
    case tenStars = 10
    case sevenPlus = 7
    case fivePlus = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return TextKey.searchFilterRatingAll.localized
        case .tenStars:
            return TextKey.searchFilterRating10.localized
        case .sevenPlus:
            return TextKey.searchFilterRating7Plus.localized
        case .fivePlus:
            return TextKey.searchFilterRating5Plus.localized
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

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        dateFilter != .all ||
        ratingFilter != .all ||
        !selectedArtists.isEmpty ||
        !selectedCities.isEmpty ||
        (dateFilter == .custom && (customDateRange.start != nil || customDateRange.end != nil))
    }

    var activeFilterCount: Int {
        var count = 0
        if dateFilter != .all { count += 1 }
        if ratingFilter != .all { count += 1 }
        if !selectedArtists.isEmpty { count += selectedArtists.count }
        if !selectedCities.isEmpty { count += selectedCities.count }
        return count
    }

    var activeFilterChips: [FilterChip] {
        var chips: [FilterChip] = []

        // Sort option (always shown, not removable)
        chips.append(FilterChip(
            id: "sort",
            title: sortOption.label,
            icon: sortOption.icon,
            isRemovable: false,
            type: .sort
        ))

        // Date filter
        if dateFilter != .all {
            let title = dateFilter == .custom
            ? customDateRangeString
            : dateFilter.label
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

        return chips
    }

    private var customDateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = customDateRange.start, let end = customDateRange.end {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = customDateRange.start {
            return TextKey.searchFilterDateFrom.localized(with: formatter.string(from: start))
        } else if let end = customDateRange.end {
            return TextKey.searchFilterDateTo.localized(with: formatter.string(from: end))
        } else {
            return TextKey.searchFilterDateChose.localized
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
    }
}

// MARK: - Filter Logic Extensions

extension ConcertFilters {

    /// Applies all filters to a list of concerts
    func apply(to concerts: [Concert]) -> [Concert] {
        var filtered = concerts

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
                return concert.rating >= ratingFilter.rawValue
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
    private func sort(concerts: [Concert]) -> [Concert] {
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
            return concerts.sorted { ($0.rating) > ($1.rating) }
        case .ratingLowest:
            return concerts.sorted { ($0.rating) < ($1.rating) }
        case .cityAZ:
            return concerts.sorted { ($0.city ?? "") < ($1.city ?? "") }
        }
    }

    /// Extracts unique artists from concerts
    func getAvailableArtists(from concerts: [Concert]) -> [String] {
        let artists = Set(concerts.map { $0.artist.name })
        return artists.sorted()
    }

    /// Extracts unique cities from concerts
    func getAvailableCities(from concerts: [Concert]) -> [String] {
        let cities = Set(concerts.compactMap { $0.city })
        return cities.sorted()
    }
}
