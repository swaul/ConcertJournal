//
//  CreateConcertSelectVenueView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.01.26.
//

import SwiftUI
import MapKit

struct CreateConcertSelectVenueView: View {

    @StateObject private var viewModel = VenueSearchViewModel()
    
    @Binding var isPresented: Bool
    
    let onSelect: (Venue) -> Void
    
    @State var selectedVenue: MKMapItem? = nil
    
    @FocusState var searchFeildFocused
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(viewModel.results, id: \.self) { venue in
                        Button {
                            selectedVenue = venue
                        } label: {
                            VenueRow(venue: venue)
                        }
                        .selectedGlass(selected: selectedVenue == venue)
                    }
                }
                .padding()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                searchField
                    .padding()
            }
            .toolbar {
                if selectedVenue != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            guard let venue = selectedVenue else { return }
                            Task {
                                do {
                                    let savedVenue = try await viewModel.saveVenue(venue: venue)
                                    isPresented = false
                                    onSelect(savedVenue)
                                } catch {
                                    print(error)
                                }
                            }
                        } label: {
                            Text("Next")
                        }
                    }
                }
            }
            .navigationTitle("Venue suchen")
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    searchFeildFocused = true
                }
            }
        }
    }

    private var searchField: some View {
        TextField("Venue oder Ort", text: $viewModel.query)
            .focused($searchFeildFocused)
            .padding()
            .glassEffect()
    }
}

struct VenueRow: View {

    let venue: MKMapItem

    var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(venue.name ?? "Unbekannte Venue")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }

                if let address = venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) {
                    HStack {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                }
            }
            .padding()
    }
}
