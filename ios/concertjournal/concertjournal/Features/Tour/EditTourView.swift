//
//  EditTourView.swift
//  concertjournal
//
//  Created by Paul Arbetit on 11.03.26.
//

import SwiftUI

struct EditTourView: View {
    
    @Environment(\.dependencies) var dependencies
    
    let tour: Tour
    
    @State var viewModel: EditTourViewModel?
    
    @State var artist: Artist
    @State var title: String
    @State var tourDescription: String
    @State var startDate: Date
    @State var endDate: Date
    
    @State private var selectArtistPresenting: Bool = false
    
    var onSave: (Tour) -> Void
    
    init(tour: Tour, onSave: @escaping (Tour) -> Void) {
        self.tour = tour
        self.onSave = onSave
        
        artist = tour.artist
        title = tour.name
        tourDescription = tour.tourDescription ?? ""
        startDate = tour.startDate
        endDate = tour.endDate
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(TextKey.edittourSectionInfo.localized)
                                .font(.cjHeadline)
                            
                            TextField(TextKey.edittourName.localized, text: $title)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            DatePicker(TextKey.edittourStartDate.localized, selection: $startDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            DatePicker(TextKey.edittourEndDate.localized, selection: $endDate, displayedComponents: .date)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .disabled(viewModel.isLoading)
                            
                            TextField(TextKey.edittourDesc.localized, text: $tourDescription, axis: .vertical)
                                .lineLimit(3...5)
                                .font(.cjBody)
                                .padding()
                                .rectangleGlass()
                                .disabled(viewModel.isLoading)
                            
                            Text(TextKey.edittourSelectArtist.localized)
                                .font(.cjBody)
                            
                            Button {
                                selectArtistPresenting = true
                            } label: {
                                if viewModel.isLoading {
                                    FlowerLoading()
                                        .frame(width: 40, height: 40)
                                } else {
                                    Text(artist.name)
                                        .font(.cjTitleF)
                                }
                            }
                            .padding()
                            .glassEffect()
                            .disabled(viewModel.isLoading)
                        }
                        .padding()
                    }
                    .sheet(isPresented: $selectArtistPresenting) {
                        CreateConcertSelectArtistView(isPresented: $selectArtistPresenting) { artist in
                            Task {
                                viewModel.isLoading = true
                                self.artist = await viewModel.getOrCreateArtist(artist: artist)
                                viewModel.isLoading = false
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                saveTourUpdates()
                            } label: {
                                Text(TextKey.genericSave.localized)
                            }
                        }
                    }
                } else {
                    FlowerLoading()
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = EditTourViewModel(tour: tour,
                                              supabaseClient: dependencies.supabaseClient,
                                              repository: dependencies.offlineConcertRepository,
                                              tourRepository: dependencies.offlineTourRepository,
                                              tourSyncManager: dependencies.tourSyncManager)
            }
            .navigationTitle(TextKey.edittourTitle.localized)
        }
    }
    
    func saveTourUpdates() {
        Task {
            guard let viewModel else { return }
            do {
                let updatedTour = try await viewModel.saveTour(name: title, startDate: startDate, endDate: endDate, description: tourDescription, artist: artist)
                onSave(updatedTour)
            } catch {
                print(error)
            }
        }
    }
}

@Observable
class EditTourViewModel {
    let tour: Tour
    
    var isLoading: Bool = false
    
    private let supabaseClient: SupabaseClientManagerProtocol
    private let repository: OfflineConcertRepositoryProtocol
    private let tourRepository: OfflineTourRepositoryProtocol
    private let tourSyncManager: TourSyncManager
    
    init(tour: Tour,
         supabaseClient: SupabaseClientManagerProtocol,
         repository: OfflineConcertRepositoryProtocol,
         tourRepository: OfflineTourRepositoryProtocol,
         tourSyncManager: TourSyncManager) {
        self.supabaseClient = supabaseClient
        self.repository = repository
        self.tourRepository = tourRepository
        self.tourSyncManager = tourSyncManager
        self.tour = tour
    }
    
    func getOrCreateArtist(artist: ArtistDTO) async -> Artist {
        let context = CoreDataStack.shared.viewContext
        let artist = await repository.fetchOrCreateArtist(from: artist, context: context)
        
        return artist
    }
    
    func saveTour(name: String, startDate: Date, endDate: Date, description: String, artist: Artist) async throws -> Tour {
        isLoading = true
        let tourDescription = description.isEmpty ? nil : description
        let updatedTour = try tourRepository.updateTour(tour,
                                                        name: name,
                                                        startDate: startDate,
                                                        endDate: endDate,
                                                        description: tourDescription,
                                                        artist: artist)
        isLoading = false
        return updatedTour
    }
    
}
