//
//  FilterView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

struct FilterSheetView: View {

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @Bindable var filters: ConcertFilters

    let availableArtists: [String]
    let availableCities: [String]

    @State private var showCustomDatePicker = false

    var body: some View {
        NavigationStack {
            List {

                sortingSection

                dateSection

                ratingSection

                // Artist Filter Section
                if !availableArtists.isEmpty {
                    artistSection
                }

                // City Filter Section
                if !availableCities.isEmpty {
                    citySection
                }
            }
            .navigationTitle("Filter & Sortierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.cjBody)
                }

                ToolbarItem(placement: .primaryAction) {
                    if filters.hasActiveFilters {
                        Button("Zurücksetzen") {
                            withAnimation {
                                filters.reset()
                            }
                        }
                        .font(.cjBody)
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var sortingSection: some View {
        // Sort Section
        Section {
            HStack {
                Text("Sortierung:")
                    .font(.cjBody)
                Menu {
                    ForEach(ConcertSortOption.allCases) { option in
                        Button {
                            filters.sortOption = option
                        } label: {
                            HStack {
                                if filters.sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(dependencies.colorThemeManager.appTint)
                                }

                                Image(systemName: option.icon)
                                    .foregroundColor(dependencies.colorThemeManager.appTint)
                                    .frame(width: 30)

                                Text(option.rawValue)
                                    .font(.cjBody)
                                    .foregroundColor(dependencies.colorThemeManager.appTint)
                            }
                        }
                    }
                } label: {
                    Label {
                        Text(filters.sortOption.rawValue)
                            .font(.cjBody)
                    } icon: {
                        Image(systemName: filters.sortOption.icon)
                    }

                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .buttonStyle(.glass)
            }
        } header: {
            Text("Sortierung")
                .font(.cjCaption)
        }
    }

    @ViewBuilder
    var dateSection: some View {
        // Date Filter Section
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Zeitraum")

                VStack {
                    Menu {
                        ForEach(DateFilterOption.allCases) { option in
                            Button {
                                filters.dateFilter = option
                                if option == .custom {
                                    showCustomDatePicker = true
                                }
                            } label: {
                                HStack {
                                    if filters.dateFilter == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(dependencies.colorThemeManager.appTint)
                                    }

                                    Image(systemName: option.icon)
                                        .foregroundColor(dependencies.colorThemeManager.appTint)
                                        .frame(width: 30)

                                    Text(option.rawValue)
                                        .font(.cjBody)
                                        .foregroundColor(dependencies.colorThemeManager.appTint)
                                }
                            }
                        }
                    } label: {
                        Text(filters.dateFilter.rawValue)
                            .font(.cjBody)
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // Custom date range display
                    if filters.dateFilter == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                "Von",
                                selection: Binding(
                                    get: { filters.customDateRange.start ?? Date() },
                                    set: { filters.customDateRange.start = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .font(.cjBody)

                            DatePicker(
                                "Bis",
                                selection: Binding(
                                    get: { filters.customDateRange.end ?? Date() },
                                    set: { filters.customDateRange.end = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .font(.cjBody)
                        }
                    }
                }
            }
        } header: {
            Text("Datum")
                .font(.cjCaption)
        }
    }

    @ViewBuilder
    var ratingSection: some View {
        // Rating Filter Section
        Section {
            HStack {
                Text("Bewertung")
                    .font(.cjBody)

                Menu {
                    ForEach(RatingFilterOption.allCases) { option in
                        Button {
                            filters.ratingFilter = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(dependencies.colorThemeManager.appTint)
                                    .frame(width: 30)

                                Text(option.displayName)
                                    .font(.cjBody)
                                    .foregroundColor(dependencies.colorThemeManager.appTint)

                                Spacer()

                                if filters.ratingFilter == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(dependencies.colorThemeManager.appTint)
                                }
                            }
                        }
                    }
                } label: {
                    Label {
                        Text(filters.ratingFilter.displayName)
                            .font(.cjBody)
                    } icon: {
                        Image(systemName: filters.ratingFilter.icon)
                    }

                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } header: {
            Text("Bewertung")
                .font(.cjCaption)
        }
    }

    @ViewBuilder
    var artistSection: some View {
        Section {
            ForEach(availableArtists, id: \.self) { artist in
                Button {
                    filters.toggleArtist(artist)
                } label: {
                    HStack {
                        Image(systemName: "music.mic")
                            .foregroundColor(dependencies.colorThemeManager.appTint.opacity(0.5))
                            .frame(width: 30)

                        Text(artist)
                            .font(.cjBody)
                            .foregroundColor(dependencies.colorThemeManager.appTint)

                        Spacer()

                        if filters.selectedArtists.contains(artist) {
                            Image(systemName: "checkmark")
                                .foregroundColor(dependencies.colorThemeManager.appTint)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Künstler")
                    .font(.cjCaption)
                Spacer()
                if !filters.selectedArtists.isEmpty {
                    Text("\(filters.selectedArtists.count) ausgewählt")
                        .font(.cjCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var citySection: some View {
        Section {
            ForEach(availableCities, id: \.self) { city in
                Button {
                    filters.toggleCity(city)
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(dependencies.colorThemeManager.appTint.opacity(0.5))
                            .frame(width: 30)

                        Text(city)
                            .font(.cjBody)
                            .foregroundColor(dependencies.colorThemeManager.appTint)

                        Spacer()

                        if filters.selectedCities.contains(city) {
                            Image(systemName: "checkmark")
                                .foregroundColor(dependencies.colorThemeManager.appTint)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Städte")
                    .font(.cjCaption)
                Spacer()
                if !filters.selectedCities.isEmpty {
                    Text("\(filters.selectedCities.count) ausgewählt")
                        .font(.cjCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Compact Filter Button

struct FilterButton: View {

    @Environment(\.dependencies) private var dependencies

    let filterCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
                .padding(8)
        }
        .buttonStyle(.glassProminent)
        .overlay(alignment: .topTrailing) {
            if filterCount > 0 {
                Text("\(filterCount)")
                    .font(.system(size: 16, weight: .bold))
                    .padding(4)
                    .background {
                        Color.red
                    }
                    .clipShape(Circle())
                    .offset(x: 6, y: -6)
            }
        }
    }
}

// MARK: - Filter Chip View

struct FilterChipView: View {

    @Environment(\.dependencies) private var dependencies

    let chip: FilterChip
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 12))

            Text(chip.title)
                .font(.cjCaption)
                .lineLimit(1)

            if chip.isRemovable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground))
        )
        .background(
            Capsule()
                .fill(dependencies.colorThemeManager.appTint.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(dependencies.colorThemeManager.appTint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Horizontal Filter Chips Bar

struct FilterChipsBar: View {

    let chips: [FilterChip]
    let onRemove: (FilterChip) -> Void
    let onTapSort: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    if chip.type == .sort {
                        // Sort chip is tappable to open filter sheet
                        Button {
                            onTapSort()
                        } label: {
                            FilterChipView(chip: chip, onRemove: {})
                        }
                        .buttonStyle(.plain)
                    } else {
                        FilterChipView(chip: chip) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onRemove(chip)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Preview

#Preview("Filter Sheet") {
    FilterSheetView(
        filters: ConcertFilters(),
        availableArtists: ["Paula Hartmann", "Seeed", "Casper", "Metallica"],
        availableCities: ["Berlin", "Hamburg", "München", "Köln"]
    )
}

#Preview("Filter Button") {
    FilterButton(filterCount: 3) {
        print("Filter tapped")
    }
}

#Preview("Filter Chips") {
    VStack {
        FilterChipsBar(
            chips: [
                FilterChip(id: "1", title: "Neueste zuerst", icon: "calendar", isRemovable: false, type: .sort),
                FilterChip(id: "2", title: "Paula Hartmann", icon: "music.mic", isRemovable: true, type: .artist("Paula Hartmann")),
                FilterChip(id: "3", title: "Berlin", icon: "location.fill", isRemovable: true, type: .city("Berlin")),
                FilterChip(id: "4", title: "5 Sterne", icon: "star.fill", isRemovable: true, type: .rating)
            ],
            onRemove: { _ in },
            onTapSort: {}
        )
    }
}
