import Combine
import MapKit
import SwiftUI
import Supabase
import SpotifyiOS
import PhotosUI

struct NewConcertVisit: Identifiable, Equatable {
    let id: UUID = UUID()
    var date: Date = .now
    var entranceTime: Date = .now
    var artistName: String = ""
    var venueName: String = ""
    var title: String = ""
    var notes: String = ""
    var rating: Int = 0
    
    var venue: Venue? = nil
    var setlist: Setlist? = nil
}

protocol SupabaseEncodable {
    func encoded() throws -> [String: AnyJSON]
}

extension View {
    @ViewBuilder
    func selectedGlass(selected: Bool, shape: some Shape = DefaultGlassEffectShape()) -> some View {
        if selected {
            self.glassEffect(.regular.tint(.blue.opacity(0.3)), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
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
    @State private var createSetlistPresenting = false

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State var selectedImages: [UIImage] = []

    @FocusState private var noteEditorFocused

    var body: some View {
        Group {
            if let artist = viewModel?.artist {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ArtistHeader(artist: artist)

                        VStack(alignment: .leading) {
                            CJDivider(title: "Zeiten", image: nil)
                                .padding(.horizontal)

                            DatePicker("Datum", selection: $draft.date, displayedComponents: [.date])
                                .padding(.horizontal)

                            DatePicker("Einlass", selection: $draft.entranceTime, displayedComponents: [.hourAndMinute])
                                .padding(.horizontal)

                            TextField("Title (optional)", text: $draft.title)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal)
                        }

                        VStack(alignment: .leading) {
                            CJDivider(title: "Location", image: nil)
                                .padding(.horizontal)

                            Button {
                                selectVenuePresenting = true
                            } label: {
                                if !draft.venueName.isEmpty {
                                    VStack(alignment: .leading) {
                                        Text(draft.venueName)
                                            .font(.cjBody)
                                        if let city = draft.venue?.city {
                                            Text(city)
                                                .font(.cjBody)
                                        }
                                    }
                                    .padding()
                                } else {
                                    Text("Venue auswählen")
                                        .padding()
                                        .font(.cjBody)
                                }
                            }
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading) {
                            CJDivider(title: "Rating", image: nil)
                                .padding(.horizontal)

                            Stepper(value: $draft.rating, in: 0...10) {
                                HStack {
                                    Text("Rating")
                                        .font(.cjBody)
                                    Spacer()
                                    Text("\(draft.rating)")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .font(.cjBody)
                                }
                            }
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading) {

                            CJDivider(title: "Meine Experience", image: nil)
                                .padding(.horizontal)

                            TextEditor(text: $draft.notes)
                                .background { Color.clear }
                                .focused($noteEditorFocused)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding()
                                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                                .padding(.horizontal)
                                .font(.cjBody)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button {
                                            noteEditorFocused = false
                                        } label: {
                                            Text("Fertig")
                                        }
                                    }
                                }
                        }

                        VStack(alignment: .leading) {
                            CJDivider(title: "Setlist", image: nil)
                                .padding(.horizontal)

                                Button {
                                    createSetlistPresenting = true
                                } label: {
                                    if let setlist = draft.setlist {
                                        VStack(alignment: .leading) {
                                            Text(setlist.id)
                                                .font(.cjBody)
                                        }
                                        .padding()
                                    } else {
                                        Text("Setlist hinzufügen")
                                            .padding()
                                            .font(.cjBody)
                                    }
                                }
                                .padding(.horizontal)
                        }

                        VStack(alignment: .leading) {
                            CJDivider(title: "Bilder", image: nil)
                                .padding(.horizontal)

                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 5,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Fotos hinzufügen", systemImage: "photo.on.rectangle.angled")
                                    .font(.cjBody)
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
                }
            } else {
                VStack(alignment: .leading) {
                    Spacer()
                    
                    Button {
                        selectArtistPresenting = true
                    } label: {
                        Text("Wähle einen Künstler")
                            .font(.cjBody)
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
            ConfirmationView(message: ConfirmationMessage(message: "Fertig"))
        })
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createSetlistPresenting) {
            CreateSetlistView(viewModel: CreateSetlistViewModel(artist: viewModel?.artist,
                                                                spotifyRepository: dependencies.spotifyRepository))
        }
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
