//
//  FilterView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

struct FilterSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var filters: ConcertFilters

    let availableArtists: [String]
    let availableCities: [String]

    @State private var showCustomDatePicker = false

    var body: some View {
        NavigationStack {
            List {
                // Sort Section
                Section {
                    ForEach(ConcertSortOption.allCases) { option in
                        Button {
                            filters.sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)

                                Text(option.rawValue)
                                    .font(.cjBody)
                                    .foregroundColor(.primary)

                                Spacer()

                                if filters.sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Sortierung")
                        .font(.cjCaption)
                }

                // Date Filter Section
                Section {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            filters.dateFilter = option
                            if option == .custom {
                                showCustomDatePicker = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)

                                Text(option.rawValue)
                                    .font(.cjBody)
                                    .foregroundColor(.primary)

                                Spacer()

                                if filters.dateFilter == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }

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
                } header: {
                    Text("Datum")
                        .font(.cjCaption)
                }

                // Rating Filter Section
                Section {
                    ForEach(RatingFilterOption.allCases) { option in
                        Button {
                            filters.ratingFilter = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)

                                Text(option.displayName)
                                    .font(.cjBody)
                                    .foregroundColor(.primary)

                                Spacer()

                                if filters.ratingFilter == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Bewertung")
                        .font(.cjCaption)
                }

                // Artist Filter Section
                if !availableArtists.isEmpty {
                    Section {
                        ForEach(availableArtists, id: \.self) { artist in
                            Button {
                                filters.toggleArtist(artist)
                            } label: {
                                HStack {
                                    Image(systemName: "music.mic")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 30)

                                    Text(artist)
                                        .font(.cjBody)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if filters.selectedArtists.contains(artist) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
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

                // City Filter Section
                if !availableCities.isEmpty {
                    Section {
                        ForEach(availableCities, id: \.self) { city in
                            Button {
                                filters.toggleCity(city)
                            } label: {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 30)

                                    Text(city)
                                        .font(.cjBody)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if filters.selectedCities.contains(city) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
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
}

// MARK: - Compact Filter Button

struct FilterButton: View {

    let filterCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22))

                if filterCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("\(filterCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

// MARK: - Filter Chip View

struct FilterChipView: View {

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
                .fill(Color.accentColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
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
        .background(Color(uiColor: .systemBackground))
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
