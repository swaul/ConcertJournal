//
//  TourView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI

struct ToursView: View {
    @Environment(\.dependencies) private var dependencies
    
    @State private var viewModel: ToursViewModel?
    @State private var selectedTab: TourTab = .upcoming
    @State private var showCreateTour = false

    enum TourTab {
        case upcoming, ongoing, past, all
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    // Picker
                    Picker("", selection: $selectedTab) {
                        Text("Kommend").tag(TourTab.upcoming)
                        Text("Aktuell").tag(TourTab.ongoing)
                        Text("Beendet").tag(TourTab.past)
                        Text("Alle").tag(TourTab.all)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Tour List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredTours, id: \.id) { tour in
                                TourCard(tour: tour)
                                    .onTapGesture {
                                        // Navigation zu Tour-Detail
                                    }
                            }
                        }
                        .padding()
                    }
                    .sheet(isPresented: $showCreateTour) {
                        CreateTourView(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = ToursViewModel(tourRepository: dependencies.offlineTourRepository, concertRepository: dependencies.offlineConcertRepository)
            }
            .navigationTitle("Touren")
            .toolbar {
                Button(action: { showCreateTour = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }

    private var filteredTours: [Tour] {
        guard let viewModel else { return [] }
        switch selectedTab {
        case .upcoming:
            return viewModel.upcomingTours
        case .ongoing:
            return viewModel.ongoingTours
        case .past:
            return viewModel.pastTours
        case .all:
            return viewModel.tours
        }
    }
}

struct TourCard: View {
    let tour: Tour
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header mit Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tour.name)
                        .font(.cjHeadline)

                    if let artist = tour.artist {
                        Text(artist.name)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                TourStatusBadge(status: tour.status)
            }

            Divider()

            // Dates und Concerts
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dauer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tour.duration)
                        .font(.cjBody)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Konzerte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tour.concertCount)")
                        .font(.cjBody)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TourStatusBadge: View {
    let status: TourStatus

    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor)
            .cornerRadius(8)
    }

    private var statusText: String {
        switch status {
        case .upcoming: return "Kommend"
        case .ongoing: return "Aktuell"
        case .finished: return "Beendet"
        }
    }

    private var statusColor: Color {
        switch status {
        case .upcoming: return .blue
        case .ongoing: return .green
        case .finished: return .gray
        }
    }
}
