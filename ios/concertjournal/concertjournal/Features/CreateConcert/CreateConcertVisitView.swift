import Combine
import MapKit
import SwiftUI
import Supabase
import SpotifyiOS
import PhotosUI

struct NewConcertVisit: Identifiable, Equatable {
    let id: UUID = UUID()
    var date: Date = .now
    var artistName: String = ""
    var venueName: String = ""
    var title: String = ""
    var notes: String = ""
    var rating: Int = 0
    
    var venue: Venue? = nil
}

protocol SupabaseEncodable {
    func encoded() throws -> [String: AnyJSON]
}

extension View {
    @ViewBuilder
    func selectedGlass(selected: Bool) -> some View {
        if selected {
            self.glassEffect(.regular.tint(.blue.opacity(0.3)))
                .glassEffectTransition(.matchedGeometry)
        } else {
            self.glassEffect(.regular)
                .glassEffectTransition(.matchedGeometry)
        }
    }
    
    @ViewBuilder
    func rectangleGlass() -> some View {
        self
            .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CreateConcertVisitView: View {
    
    @Environment(\.navigationManager) private var navigationManager
    @Environment(\.dependencies) private var dependencies

    @State var viewModel: CreateConcertVisitViewModel?

    @State private var draft = NewConcertVisit()
    @State private var presentConfirmation = false
    
    @State private var selectArtistPresenting = false
    @State private var selectVenuePresenting = false
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State var selectedImages: [UIImage] = []

    var body: some View {
        Group {
            if let artist = viewModel?.artist {
                ScrollView {
                    VStack(alignment: .leading) {
                        ArtistHeader(artist: artist)
                        
                        DatePicker("Concert date and entry time", selection: $draft.date, displayedComponents: [.hourAndMinute, .date])
                            .padding(.horizontal)
                            .glassEffect()
                            .padding(.horizontal)
                        
                        TextField("Title (optional)", text: $draft.title)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .glassEffect()
                            .padding(.horizontal)

                        Button {
                            selectVenuePresenting = true
                        } label: {
                            if !draft.venueName.isEmpty {
                                VStack(alignment: .leading) {
                                    Text(draft.venueName)
                                    if let city = draft.venue?.city {
                                        Text(city)
                                    }
                                }
                                .padding()
                            } else {
                                Text("Select Venue (optional)")
                                    .padding()
                            }
                        }
                        .buttonStyle(.glass)
                        .padding(.horizontal)

                        Stepper(value: $draft.rating, in: 0...10) {
                            HStack {
                                Text("Rating")
                                Spacer()
                                Text("\(draft.rating)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .glassEffect()
                        .padding(.horizontal)

                        TextEditor(text: $draft.notes)
                            .background { Color.clear }
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding()
                            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                            .padding(.horizontal)
                        
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 5,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Fotos hinzufügen", systemImage: "photo.on.rectangle.angled")
                        }
                        .padding()
                        .buttonStyle(.glass)
                        .padding(.horizontal)
                        .onChange(of: selectedPhotoItems) { _, newItems in
                            Task {
                                await loadSelectedImages(from: newItems)
                            }
                        }
                        
                        if !selectedImages.isEmpty {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 12
                            ) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 100)
                                            .clipped()
                                            .cornerRadius(12)
                                        
                                        Button {
                                            selectedPhotoItems.remove(at: index)
                                            removeImage(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    Spacer()
                    
                    Button {
                        selectArtistPresenting = true
                    } label: {
                        Text("Select Artist")
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.bottom, 32)
                }
                .onAppear {
                    selectArtistPresenting = true
                }
            }
        }
        .task {
            guard viewModel == nil else { return }
            self.viewModel = CreateConcertVisitViewModel(artistRepository: dependencies.artistRepository,
                                                         concertRepository: dependencies.concertRepository,
                                                         userSessionManager: dependencies.userSessionManager,
                                                         photoRepository: dependencies.photoRepository)
        }
        .sheet(isPresented: $presentConfirmation, onDismiss: {
            navigationManager.pop()
        }, content: {
            ConfirmationView()
        })
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $selectArtistPresenting) {
            CreateConcertSelectArtistView(isPresented: $selectArtistPresenting, didSelectArtist: { artist in
                viewModel?.artist = artist
                self.selectArtistPresenting = false
            })
        }
        .sheet(isPresented: $selectVenuePresenting) {
            CreateConcertSelectVenueView(isPresented: $selectVenuePresenting, onSelect: { venue in
                draft.venueName = venue.name
                draft.venue = venue
            })
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { navigationManager.pop() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }
    
    private func save() {
        Task {
            do {
                guard let visitId = try await viewModel?.createVisit(from: draft) else { return }
                try await viewModel?.uploadSelectedPhotos(selectedImages: selectedImages, visitId: visitId)
                showConfirmation()
            } catch {
                print("failed to create visit: \(error)")
            }
        }
    }
        
    @MainActor
    func loadSelectedImages(from items: [PhotosPickerItem]) async {
        selectedImages.removeAll()

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }
    
    func removeImage(at index: Int) {
        selectedImages.remove(at: index)
    }
    
    func showConfirmation() {
        presentConfirmation = true
    }
}

#Preview {
    CreateConcertVisitView()
}
