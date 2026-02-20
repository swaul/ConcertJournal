//
//  CreateConcertSelectVenueView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.01.26.
//

import SwiftUI
import MapKit

struct CreateConcertSelectVenueView: View {
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: VenueSearchViewModel?

    @Binding var isPresented: Bool
    
    let onSelect: (VenueDTO) -> Void

    @State var selectedVenue: MKMapItem? = nil
    
    @FocusState var searchFeildFocused
        
    @State var searchFeildFocusedAnimated: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Venue auswählen")
            .task {
                guard viewModel == nil else { return }
                viewModel = VenueSearchViewModel()
            }
        }
    }

    @ViewBuilder
    private func viewWithViewModel(viewModel: VenueSearchViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(viewModel.results, id: \.identifier) { venue in
                    Button {
                        selectedVenue = venue
                    } label: {
                        VenueRow(venue: venue)
                    }
                    .selectedGlass(selected: selectedVenue?.identifier == venue.identifier, shape: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .onChange(of: searchFeildFocused, { oldValue, newValue in
            withAnimation(.bouncy) {
                searchFeildFocusedAnimated = newValue
            }
        })
        .safeAreaInset(edge: .bottom) {
            searchField(query: $viewModel.query)
                .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchFeildFocused = true
            }
        }
        .toolbar {
            if selectedVenue != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let venue = selectedVenue else { return }
                        HapticManager.shared.buttonTap()
                        Task {
                            do {
                                let savedVenue = try await viewModel.parseVenue(venue: venue)
                                isPresented = false
                                onSelect(savedVenue)
                            } catch {
                                print(error)
                            }
                        }
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func searchField(query: Binding<String>) -> some View {
        HStack {
            TextField("Venue oder Ort", text: query)
                .autocorrectionDisabled()
                .focused($searchFeildFocused)
                .font(.cjBody)
                .padding()
                .glassEffect()
            
            if searchFeildFocusedAnimated {
                Button {
                    HapticManager.shared.buttonTap()
                    searchFeildFocused = false
                } label: {
                    Text("Fertig")
                        .font(.cjBody)
                }
                .buttonStyle(.glass)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

struct VenueRow: View {

    let venue: MKMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(venue.name ?? "Unbekannte Venue")
                    .font(.cjHeadline)
                    .foregroundStyle(Color("textColor"))
                Spacer()
            }
            if let address = venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) {
                    Text(address)
                        .font(.cjCaption)
                        .foregroundStyle(Color("textColor"))
                        .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .foregroundStyle(Color("textColor"))
    }
}
