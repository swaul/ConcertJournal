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

    var ticket: Ticket? = nil
    var travel: Travel? = nil
    var venue: Venue? = nil
    var setlistItems: [TempCeateSetlistItem] = []
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
        self.glassEffect(in: RoundedRectangle(cornerRadius: 20))
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
    @State private var presentTicketEdit = false

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State var selectedImages: [UIImage] = []

    @FocusState private var noteEditorFocused

    @State private var savingConcertPresenting: Bool = false
    
    var body: some View {
        Group {
            if let artist = viewModel?.artist {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ArtistHeader(artist: artist)

                        timeSection()

                        venueSection()

                        travelSection()

                        ticketSection()

                        ratingSection()

                        noteSection()

                        setlistSection()

                        imagesSection()
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
                                                         photoRepository: dependencies.photoRepository,
                                                         setlistRepository: dependencies.setlistRepository)
        }
        .sheet(isPresented: $presentConfirmation, onDismiss: {
            navigationManager.pop()
        }, content: {
            ConfirmationView(message: ConfirmationMessage(message: "Fertig"))
        })
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createSetlistPresenting) {
            CreateSetlistView(viewModel: CreateSetlistViewModel(currentSelection: draft.setlistItems,
                                                                artist: viewModel?.artist,
                                                                spotifyRepository: dependencies.spotifyRepository,
                                                                setlistRepository: dependencies.setlistRepository)) { setlistItems in
                draft.setlistItems = setlistItems
                createSetlistPresenting = false
            }
        }
        .sheet(isPresented: $selectArtistPresenting) {
            CreateConcertSelectArtistView(isPresented: $selectArtistPresenting, didSelectArtist: { artist in
                withAnimation {
                    self.selectArtistPresenting = false
                } completion: {
                    withAnimation {
                        viewModel?.artist = artist
                    }
                }
            })
        }
        .sheet(isPresented: $selectVenuePresenting) {
            CreateConcertSelectVenueView(isPresented: $selectVenuePresenting, onSelect: { venue in
                draft.venueName = venue.name
                draft.venue = venue
            })
        }
        .sheet(isPresented: $presentTicketEdit) {
            CreateConcertTicket(artist: viewModel?.artist) { ticketInfo in
                draft.ticket = ticketInfo
                presentTicketEdit = false
            }
        }
        .sheet(isPresented: $savingConcertPresenting) {
            ZStack {
                VStack {
                    ProgressView()
                        .tint(dependencies.colorThemeManager.appTint)
                    Text("Speichern..")
                        .font(.cjBody)
                }
            }
            .frame(height: 250)
            .presentationDetents([.height(250)])
            .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { navigationManager.pop() }
                    .font(.cjBody)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .font(.cjBody)
            }
        }
    }
    
    private func save() {
        Task {
            do {
                guard let visitId = try await viewModel?.createVisit(from: draft) else { return }
                savingConcertPresenting = true
                try await viewModel?.uploadSelectedPhotos(selectedImages: selectedImages, visitId: visitId)
                try await dependencies.concertRepository.reloadConcerts()
                savingConcertPresenting = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfirmation()
                }
            } catch {
                print("failed to create visit: \(error)")
            }
        }
    }

    @ViewBuilder
    func timeSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Zeiten", image: nil)
                .padding(.horizontal)

            DatePicker("Datum", selection: $draft.date, displayedComponents: [.date])
                .padding(.horizontal)
                .font(.cjBody)

            DatePicker("Einlass", selection: $draft.entranceTime, displayedComponents: [.hourAndMinute])
                .padding(.horizontal)
                .font(.cjBody)

            TextField("Titel (optional)", text: $draft.title)
                .textInputAutocapitalization(.words)
                .font(.cjBody)
                .padding()
                .glassEffect()
                .padding()
        }
    }

    @ViewBuilder
    func venueSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Location", image: nil)
                .padding(.horizontal)

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
            }

            Button {
                selectVenuePresenting = true
            } label: {
                Text("Venue auswählen")
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    func imagesSection() -> some View {
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

    @State var presentTravelSection: Bool = false

    @ViewBuilder
    func travelSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Reise", image: nil)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                if let travel = draft.travel {
                    VStack(alignment: .leading, spacing: 8) {

                        if let travelType = travel.travelType {
                            Group {
                                switch travelType {
                                case .car:
                                    Text("Du bist mit dem Auto zur Location gekommen")
                                        .font(.cjBody)
                                case .plane:
                                    Text("Du hast für die Reise ein Flugzeug genommen")
                                        .font(.cjBody)
                                case .bike:
                                    Text("Du bist mit dem Fahrrad zur Location gekommen")
                                        .font(.cjBody)
                                case .foot:
                                    Text("Die Location war zu Fuß errreichbar")
                                        .font(.cjBody)
                                case .train:
                                    Text("Du hast den Zug genommen")
                                        .font(.cjBody)
                                }
                            }
                        }
                        if let travelDuration = travel.travelDuration {
                            let parsedDuration = DurationParser.format(travelDuration)
                            Text("Die Reise hat \(parsedDuration) gedauert.")
                                .font(.cjBody)
                        }
                        if let travelDistance = travel.travelDistance {
                            let parsedDistance = DistanceParser.format(travelDistance)
                            Text("Der Weg war \(parsedDistance) lang.")
                                .font(.cjBody)
                        }
                        if let travelExpenses = travel.travelExpenses {
                            Text("Die Anreise hat dich \(travelExpenses.formatted) gekostet.")
                                .font(.cjBody)
                        }
                        if let hotelExpenses = travel.hotelExpenses {
                            Text("Und für die Übernachtung hast du \(hotelExpenses.formatted) gezahlt.")
                                .font(.cjBody)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))

                    Button {
                        presentTravelSection = true
                    } label: {
                        Text("Reiseinfos ändern")
                            .font(.cjBody)
                    }
                    .padding()
                    .glassEffect()
                } else {
                    Button {
                        presentTravelSection = true
                    } label: {
                        Text("Reiseinfos hinzufügen")
                            .font(.cjBody)
                    }
                    .padding()
                    .glassEffect()
                }
            }
            .padding(.horizontal)
            .font(.cjBody)
        }
        .sheet(isPresented: $presentTravelSection) {
            CreateConcertTravelView(travel: draft.travel) { travel in
                draft.travel = travel
                presentTravelSection = false
            }
        }
    }

    @ViewBuilder
    func ticketSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Ticket", image: nil)
                .padding(.horizontal)
            
            if let ticket = draft.ticket {
                VStack(alignment: .leading) {
                    
                    Text(ticket.ticketType.label)
                        .font(.cjTitle)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    ticket.ticketCategory.color
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .overlay {
                            Text(ticket.ticketCategory.label)
                                .font(.cjTitleF)
                        }
                    
                    switch ticket.ticketType {
                    case .seated:
                        Grid {
                            GridRow {
                                if ticket.seatBlock != nil {
                                    Text("Block")
                                        .font(.cjHeadline)
                                }
                                if ticket.seatRow != nil {
                                    Text("Reihe")
                                        .font(.cjHeadline)
                                }
                                if ticket.seatNumber != nil {
                                    Text("Platz")
                                        .font(.cjHeadline)
                                }
                            }
                            GridRow {
                                if let block = ticket.seatBlock {
                                    Text(block)
                                        .font(.cjTitle)
                                }
                                if let row = ticket.seatRow {
                                    Text(row)
                                        .font(.cjTitle)
                                }
                                if let seatNumber = ticket.seatNumber {
                                    Text(seatNumber)
                                        .font(.cjTitle)
                                }
                            }
                        }
                    case .standing:
                        if let standingPosition = ticket.standingPosition {
                            Text(standingPosition)
                                .font(.cjBody)
                        }
                    }
                    
                    if let notes = ticket.notes {
                        Text(notes)
                            .font(.cjBody)
                            .padding(.horizontal)
                    }
                    
                    Button {
                        presentTicketEdit = true
                    } label: {
                        Text("Ticket infos hinzufügen")
                            .font(.cjBody)
                    }
                    .padding()
                    .glassEffect()
                    .padding(.horizontal)
                }
            } else {
                Button {
                    presentTicketEdit = true
                } label: {
                    Text("Ticket infos hinzufügen")
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    func ratingSection() -> some View {
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
    }

    @ViewBuilder
    func noteSection() -> some View {
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
    }

    @ViewBuilder
    func setlistSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Setlist", image: nil)
                .padding(.horizontal)

            if !draft.setlistItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(draft.setlistItems, id: \.id) { item in
                        makeSetlistItemView(with: item)
                    }
                    Button {
                        createSetlistPresenting = true
                    } label: {
                        Text("Setlist bearbeiten")
                            .padding()
                            .glassEffect()
                            .font(.cjBody)
                    }
                }
                .padding(.horizontal)
            } else {
                Button {
                    createSetlistPresenting = true
                } label: {
                    Text("Setlist hinzufügen")
                        .padding()
                        .glassEffect()
                        .font(.cjBody)
                }
                .padding(.horizontal)
                if dependencies.userSessionManager.user?.identities?.contains(where: { $0.provider == "spotify" }) == true {
                    Button {
                        playlistPickerPresenting = true
                    } label: {
                        HStack {
                            Image("Spotify")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 38)
                            Text("Aus Spotify importieren")
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(6)
                    .background { Color.black }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .sheet(isPresented: $playlistPickerPresenting) {
                        SpotifyPlaylistPicker { playlist in
                            parsePlaylistToSetlist(playlist)
                        }
                    }
                }
            }
        }
    }

    func parsePlaylistToSetlist(_ playlist: SpotifyPlaylist) {
        Task {
            try await dependencies.userSessionManager.refreshSpotifyProviderTokenIfNeeded()
            guard let providerToken = dependencies.userSessionManager.providerToken else {
                return
            }

            logInfo("Provider token found, creating playlists", category: .viewModel)

            do {
                let setlistItems = try await dependencies.spotifyRepository.importPlaylistToSetlist(playlistId: playlist.id)
                draft.setlistItems = setlistItems
            } catch {
                print(error)
            }
        }
    }

    @State var playlistPickerPresenting: Bool = false

    @ViewBuilder
    func makeSetlistItemView(with item: TempCeateSetlistItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let albumName = item.albumName {
                Text(albumName)
                    .font(.cjCaption)
                    .padding(.leading)
                    .padding(.top)
            } else {
                Text(" ")
            }
            HStack {
                Group {
                    AsyncImage(url: URL(string: item.coverImage ?? ""), content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                    }, placeholder: {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 40, height: 40)
                    })
                }
                .clipShape(.circle)
                .frame(width: 40, height: 40)
                .padding(.leading)

                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.cjBody)
                        .bold()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.artistNames)
                        .font(.cjBody)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                }
                .frame(maxWidth: .infinity)
                .padding(.trailing)
            }
            .padding(.bottom)

        }
        .rectangleGlass()
        .onAppear {
            print(item.title)
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
