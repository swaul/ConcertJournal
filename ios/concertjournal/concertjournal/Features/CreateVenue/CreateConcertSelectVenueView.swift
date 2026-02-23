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
    @State var selectedKnownVenue: VenueDTO? = nil

    @FocusState var searchFeildFocused

    @State var searchFeildFocusedAnimated: Bool = false
    @State var isSearchingAnimated: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .background {
                Color.background
                    .ignoresSafeArea()
            }
            .navigationTitle("Venue auswählen")
            .task {
                guard viewModel == nil else { return }
                viewModel = VenueSearchViewModel(offlineConcertRepository: dependencies.offlineConcertRepository)
            }
        }
    }

    @ViewBuilder
    private func viewWithViewModel(viewModel: VenueSearchViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading) {
                if isSearchingAnimated {
                    SearchingView(searchContent: "Venue")
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.cjBody)
                        .padding()
                } else if !viewModel.didSearch {
                    ForEach(viewModel.currentVenues, id: \.id) { venue in
                        Button {
                            HapticManager.shared.buttonTap()
                            selectedKnownVenue = venue
                        } label: {
                            KnownVenueRow(venue: venue)
                        }
                        .selectedGlass(selected: selectedKnownVenue?.id == venue.id, shape: RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    ForEach(viewModel.results, id: \.identifier) { venue in
                        Button {
                            HapticManager.shared.buttonTap()
                            selectedVenue = venue
                        } label: {
                            VenueRow(venue: venue)
                        }
                        .selectedGlass(selected: selectedVenue?.identifier == venue.identifier, shape: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: searchFeildFocused, { oldValue, newValue in
            withAnimation(.bouncy) {
                searchFeildFocusedAnimated = newValue
            }
        })
        .onChange(of: viewModel.isLoading, { _, newValue in
            withAnimation {
                isSearchingAnimated = newValue
            }
        })
        .safeAreaInset(edge: .bottom) {
            searchField(query: $viewModel.query)
                .padding()
        }
        .toolbar {
            if selectedVenue != nil || selectedKnownVenue != nil {
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
                        Text(TextKey.save.localized)
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
                    Text(TextKey.done.localized)
                        .font(.cjBody)
                }
                .buttonStyle(.glass)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

struct VenueRow: View {
    @Environment(\.dependencies) private var dependencies

    let venue: MKMapItem

    var body: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .resizable()
                .frame(width: 28, height: 28)
                .aspectRatio(contentMode: .fit)
                .padding()
                .foregroundStyle(dependencies.colorThemeManager.appTint)
                .background(Color.divider)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.name ?? "Unbekannte Venue")
                        .font(.cjHeadline)
                        .foregroundStyle(Color.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let address = venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) {
                        Text(address)
                            .font(.cjCaption)
                            .foregroundStyle(Color.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .foregroundStyle(Color.text)
    }
}

struct KnownVenueRow: View {
    @Environment(\.dependencies) private var dependencies

    let venue: VenueDTO

    var body: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .resizable()
                .frame(width: 28, height: 28)
                .aspectRatio(contentMode: .fit)
                .padding()
                .foregroundStyle(dependencies.colorThemeManager.appTint)
                .background(Color.divider)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(venue.name)
                    .font(.cjHeadline)
                    .foregroundStyle(Color.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(venue.formattedAddress)
                    .font(.cjCaption)
                    .foregroundStyle(Color.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .foregroundStyle(Color.text)
    }
}
