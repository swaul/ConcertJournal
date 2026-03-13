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
    @State private var showTourDetail: Tour? = nil
    
    enum TourTab {
        case upcoming, ongoing, past, all
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let viewModel {
                // Picker
                Picker("", selection: $selectedTab) {
                    Text(TextKey.toursStatusUpcoming.localized).tag(TourTab.upcoming)
                    Text(TextKey.toursStatusCurrent.localized).tag(TourTab.ongoing)
                    Text(TextKey.toursStatusPast.localized).tag(TourTab.past)
                    Text(TextKey.toursStatusAll.localized).tag(TourTab.all)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tour List
                ScrollView {
                    VStack(spacing: 12) {
                        if !filteredTours.isEmpty {
                            ForEach(filteredTours, id: \.id) { tour in
                                Button {
                                    showTourDetail = tour
                                } label: {
                                    TourCard(tour: tour)
                                }
                            }
                        } else {
                            Text(TextKey.toursNoTours.localized)
                                .font(.cjBody)
                        }
                    }
                    .padding()
                }
                .sheet(isPresented: $showCreateTour) {
                    CreateTourView {
                        viewModel.loadTours()
                    }
                }
                .sheet(item: $showTourDetail) { tour in
                    TourDetailView(tour: tour)
                }
            } else {
                LoadingView()
            }
        }
        .background {
            Color.background
                .ignoresSafeArea()
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = ToursViewModel(tourRepository: dependencies.offlineTourRepository, concertRepository: dependencies.offlineConcertRepository)
        }
        .onChange(of: viewModel?.tours) { _, allTours in
            if viewModel?.upcomingTours.isEmpty == false {
                selectedTab = .upcoming
            } else if viewModel?.ongoingTours.isEmpty == false {
                selectedTab = .ongoing
            } else if viewModel?.pastTours.isEmpty == false {
                selectedTab = .past
            } else if viewModel?.tours.isEmpty == false {
                selectedTab = .all
            }
        }
        .navigationTitle(TextKey.toursTitle.localized)
        .toolbar {
            Button(action: { showCreateTour = true }) {
                Image(systemName: "plus.circle.fill")
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
                    
                    Text(tour.artist.name)
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                TourStatusBadge(status: tour.status)
            }
            
            Divider()
            
            // Dates und Concerts
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TextKey.toursDuration.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tour.duration)
                        .font(.cjBody)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(TextKey.toursConcerts.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tour.concertCount)")
                        .font(.cjBody)
                }
                
                Spacer()
            }
        }
        .padding()
        .rectangleGlass()
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
        case .upcoming: return TextKey.toursStatusUpcoming.localized
        case .ongoing: return TextKey.toursStatusCurrent.localized
        case .finished: return TextKey.toursStatusPast.localized
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
