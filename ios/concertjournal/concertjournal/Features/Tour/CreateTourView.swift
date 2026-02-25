//
//  CreateTourView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI

struct SelectTourView: View {

    @Environment(\.dependencies) var dependencies

    @State var viewModel: SelectTourViewModel?
    @State var createTourPresenting: Bool = false

    var currentTour: Tour?
    var contextArtist: Artist?
    var onSelect: (Tour) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    loadedView(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = SelectTourViewModel(tourRepository: dependencies.offlineTourRepository)
            }
            .navigationTitle("Tour Auswählen")
        }
    }

    @ViewBuilder
    func loadedView(viewModel: SelectTourViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading) {
                ForEach(viewModel.tours, id: \.id) { tour in
                    Button {
                        onSelect(tour)
                    } label: {
                        makeTourView(tour: tour)
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button {
                createTourPresenting = true
            } label: {
                Label("Neue Tour erstellen", systemImage: "plus.circle")
                    .font(.cjBody)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .glassEffect()
            .padding()
        }
        .tint(dependencies.colorThemeManager.appTint)
        .sheet(isPresented: $createTourPresenting) {
            CreateTourView(contextArtist: contextArtist) {
                createTourPresenting = false
                viewModel.loadTours()
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    func makeTourView(tour: Tour) -> some View {
        HStack {
            Text(tour.name)
                .font(.cjBody)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .rectangleGlass()
    }
}

@Observable
class SelectTourViewModel {

    var tours = [Tour]()

    let tourRepository: OfflineTourRepositoryProtocol

    init(tourRepository: OfflineTourRepositoryProtocol) {
        self.tourRepository = tourRepository

        loadTours()
    }

    func loadTours() {
        do {
            tours = try tourRepository.getAllTours()
        } catch {
            logError("Error loading tours", error: error)
        }
    }
}

struct CreateTourView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencies) var dependencies

    @State var viewModel: CreateTourViewModel?

    @State private var tourName = ""
    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(86400 * 7)
    @State private var tourDescription = ""
    @State private var selectedArtist: ArtistDTO?

    @State private var selectArtistPresenting: Bool = false

    var onCreate: () -> Void

    init(contextArtist: Artist? = nil, onCreate: @escaping () -> Void) {
        self._selectedArtist = State(initialValue: contextArtist?.toDTO())
        self.onCreate = onCreate
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Tour Informationen")
                                .font(.cjHeadline)

                            TextField("Tour Name", text: $tourName)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)

                            DatePicker("Startdatum", selection: $startDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)

                            DatePicker("Enddatum", selection: $endDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)

                            TextField("Beschreibung (optional)", text: $tourDescription, axis: .vertical)
                                .lineLimit(3...5)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)

                            Text("Künstler")
                                .font(.cjBody)

                            Button {
                                selectArtistPresenting = true
                            } label: {
                                if viewModel.isLoading {
                                    ProgressView()
                                } else if let selectedArtist {
                                    Text(selectedArtist.name)
                                } else {
                                    Text("Künstler wählen")
                                }
                            }
                            .padding()
                            .glassEffect()
                            .disabled(viewModel.isLoading)
                        }
                        .padding()
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Erstellen") {
                                guard let selectedArtist else { return }
                                viewModel.createTour(
                                    name: tourName,
                                    startDate: startDate,
                                    endDate: endDate,
                                    artist: selectedArtist,
                                    description: tourDescription.isEmpty ? nil : tourDescription
                                )
                                dismiss()
                            }
                            .disabled(tourName.isEmpty || selectedArtist == nil || viewModel.isLoading)
                        }
                    }
                } else {
                    LoadingView()
                }
            }
            .sheet(isPresented: $selectArtistPresenting) {
                CreateConcertSelectArtistView(isPresented: $selectArtistPresenting) { artist in
                    self.selectedArtist = artist
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = CreateTourViewModel(tourRepository: dependencies.offlineTourRepository, tourSyncManager: dependencies.tourSyncManager)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Neue Tour")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@Observable
class CreateTourViewModel {

    let tourRepository: OfflineTourRepositoryProtocol
    let tourSyncManager: TourSyncManagerProtocol
    var isLoading: Bool = false

    init(tourRepository: OfflineTourRepositoryProtocol, tourSyncManager: TourSyncManagerProtocol) {
        self.tourRepository = tourRepository
        self.tourSyncManager = tourSyncManager
    }

    func createTour(name: String, startDate: Date, endDate: Date, artist: ArtistDTO, description: String? = nil) {
        Task {
            isLoading = true
            async let createTask = tourRepository.createTour(name: name, startDate: startDate, endDate: endDate, artist: artist, description: description)
            async let minWaitTask: Void = Task.sleep(for: .seconds(2))

            do {
                let (tour, _) = try await (createTask, minWaitTask)
                let serverTour = try await tourSyncManager.createTour(tour)
                isLoading = false
            } catch {

            }
        }
    }

}
