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

    var onSelect: (Tour) -> Void

    var body: some View {
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
    }

    @ViewBuilder
    func loadedView(viewModel: SelectTourViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(viewModel.tours, id: \.id) { tour in
                    Button {
                        onSelect(tour)
                    } label: {
                        makeTourView(tour: tour)
                    }
                }
                Button {
                    createTourPresenting = true
                } label: {
                    Label("Neue Tour erstellen", systemImage: "plus.circle")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $createTourPresenting) {
            CreateTourView {
                viewModel.loadTours()
            }
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

        }
    }
}

struct CreateTourView: View {
    @Environment(\.dismiss) var dismiss

    @State var viewModel: CreateTourViewModel?

    @State private var tourName = ""
    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(86400 * 7)
    @State private var tourDescription = ""
    @State private var selectedArtist: Artist? = nil

    var onCreate: (Tour) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    Form {
                        Section("Tour-Informationen") {
                            TextField("Tour Name", text: $tourName)

                            DatePicker("Startdatum", selection: $startDate, displayedComponents: .date)
                            DatePicker("Enddatum", selection: $endDate, displayedComponents: .date)

                            TextField("Beschreibung (optional)", text: $tourDescription, axis: .vertical)
                                .lineLimit(3...5)
                        }

                        Section("Künstler") {
                            Text("Künstler-Auswahl Feature")
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Erstellen") {
                                viewModel.createTour(
                                    name: tourName,
                                    startDate: startDate,
                                    endDate: endDate,
                                    artist: selectedArtist,
                                    description: tourDescription.isEmpty ? nil : tourDescription
                                )
                                dismiss()
                            }
                            .disabled(tourName.isEmpty)
                        }
                    }
                } else {
                    LoadingView()
                }
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

    init(tourRepository: OfflineTourRepositoryProtocol) {
        self.tourRepository = tourRepository
    }

    func createTour(name: String, startDate: Date, endDate: Date, artist: Artist? = nil, description: String? = nil) {
        _ = tourRepository.createTour(name: name, startDate: startDate, endDate: endDate, artist: artist, description: description)
    }

}
