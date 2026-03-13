//
//  CreateTourView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI
import CoreData

struct SelectTourWithTempArtist: View {
    
    @Environment(\.dependencies) var dependencies
    
    @State var tempArtist: ArtistDTO
    @State var viewModel: SelectTourViewModel?
    
    var onSelect: (Tour) -> Void
    
    var body: some View {
        Group {
            if let viewModel {
                SelectTourView(viewModel: viewModel, contextArtist: viewModel.contextArtist, onSelect: onSelect)
            } else {
                LoadingView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = SelectTourViewModel(tempArtist: tempArtist, tourRepository: dependencies.offlineTourRepository)
        }
    }
}

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
            .navigationTitle(TextKey.selecttourTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
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
                Label(TextKey.selecttourCreateTour.localized, systemImage: "plus.circle")
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
    var contextArtist: Artist?
    
    let tourRepository: OfflineTourRepositoryProtocol
    
    var tempArtist: ArtistDTO?
    
    init(tempArtist: ArtistDTO? = nil, tourRepository: OfflineTourRepositoryProtocol) {
        self.tourRepository = tourRepository
        self.tempArtist = tempArtist
        
        loadTours()
        
        contextArtist = fetchLocalArtistIfExists(artistDto: tempArtist)
    }
    
    private func fetchLocalArtistIfExists(artistDto: ArtistDTO?) -> Artist? {
        guard let artistDto else { return nil }
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", artistDto.id)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        guard let spotifyId = artistDto.spotifyArtistId, !spotifyId.isEmpty else { return nil }
        request.predicate = NSPredicate(format: "spotifyArtistId == %@", spotifyId)
        
        if let existing = try? context.fetch(request).first {
            existing.serverId = artistDto.id
            existing.syncStatus = SyncStatus.synced.rawValue
            return existing
        }
        
        return nil
    }
    
    func loadTours() {
        do {
            let tours = try tourRepository.getAllTours()
            self.tours = tours
        } catch {
            logError("Error loading tours", error: error)
        }
    }

    func deleteTour(tour: Tour) {
        do {
            try tourRepository.deleteTour(tour)
        } catch {
            print("Error", error)
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
                            Text(TextKey.createtourSectionInfo.localized)
                                .font(.cjHeadline)
                            
                            TextField(TextKey.createtourName.localized, text: $tourName)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            DatePicker(TextKey.createtourStartDate.localized, selection: $startDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            DatePicker(TextKey.createtourEndDate.localized, selection: $endDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            TextField(TextKey.createtourDesc.localized, text: $tourDescription, axis: .vertical)
                                .lineLimit(3...5)
                                .font(.cjBody)
                                .padding()
                                .rectangleGlass()
                                .disabled(viewModel.isLoading)
                            
                            Text(TextKey.createtourSectionArtist.localized)
                                .font(.cjBody)
                            
                            Button {
                                selectArtistPresenting = true
                            } label: {
                                if viewModel.isLoading {
                                    FlowerLoading()
                                    .frame(width: 40, height: 40)
                                } else if let selectedArtist {
                                    Text(selectedArtist.name)
                                        .font(.cjTitleF)
                                } else {
                                    Text(TextKey.createtourSelectArtist.localized)
                                        .font(.cjHeadline)
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
                            Button(TextKey.createtourCreate.localized) {
                                guard let selectedArtist else { return }
                                Task {
                                    await viewModel.createTour(
                                        name: tourName,
                                        startDate: startDate,
                                        endDate: endDate,
                                        artist: selectedArtist,
                                        description: tourDescription.isEmpty ? nil : tourDescription
                                    )
                                    onCreate()
                                }
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
                viewModel = CreateTourViewModel(supabaseClient: dependencies.supabaseClient, tourRepository: dependencies.offlineTourRepository, tourSyncManager: dependencies.tourSyncManager)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .navigationTitle(TextKey.createtourTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@Observable
class CreateTourViewModel {
    
    let supabaseClient: SupabaseClientManagerProtocol
    let tourRepository: OfflineTourRepositoryProtocol
    let tourSyncManager: TourSyncManager
    var isLoading: Bool = false
    
    init(supabaseClient: SupabaseClientManagerProtocol, tourRepository: OfflineTourRepositoryProtocol, tourSyncManager: TourSyncManager) {
        self.supabaseClient = supabaseClient
        self.tourRepository = tourRepository
        self.tourSyncManager = tourSyncManager
    }
    
    func createTour(name: String, startDate: Date, endDate: Date, artist: ArtistDTO, description: String? = nil) async {
        isLoading = true
        async let createTask = tourRepository.createTour(name: name, startDate: startDate, endDate: endDate, artist: artist, description: description)
        async let minWaitTask: Void = Task.sleep(for: .seconds(2))
        
        _ = try? await (createTask, minWaitTask)
            
        isLoading = false
    }
    
}
