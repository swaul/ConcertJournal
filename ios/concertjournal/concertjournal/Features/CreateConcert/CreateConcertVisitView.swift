import Combine
import MapKit
import SwiftUI
import Supabase
import SpotifyiOS
import PhotosUI

struct NewConcertVisit: Identifiable, Equatable {
    
    let id: UUID = UUID()
    var date: Date = .now
    var openingTime: Date? = nil
    var artistName: String = ""
    var venueName: String = ""
    var title: String = ""
    var notes: String = ""
    var rating: Int?

    var supportActs: [ArtistDTO] = []
    var ticket: TicketDTO? = nil
    var travel: TravelDTO? = nil
    var venue: VenueDTO? = nil
    var setlistItems: [TempCeateSetlistItem] = []

    init(importeConcert: ImportedConcert) {
        self.date = importeConcert.date ?? .now
        self.openingTime = importeConcert.date ?? .now
        self.artistName = importeConcert.artistName ?? ""
        self.venueName = importeConcert.venueName ?? ""
        self.title = importeConcert.title ?? ""
        self.notes = importeConcert.notes ?? ""
        self.rating = 0

        self.ticket = nil
        self.travel = nil
        self.venue = importeConcert.venue
        self.setlistItems = []
    }
    
    init(ticketInfo: ExtendedTicketInfo) {
        self.date = ticketInfo.date ?? .now
        self.openingTime = ticketInfo.date ?? .now
        self.artistName = ticketInfo.artistName
        self.venueName = ticketInfo.venueName ?? ""
        self.title = ""
        self.notes = ""
        self.rating = nil

        self.ticket = nil
        self.travel = nil
        self.venue = nil
        self.setlistItems = []
    }

    init() {
        self.date = .now
        self.openingTime = .now
        self.artistName = ""
        self.venueName = ""
        self.title = ""
        self.notes = ""
        self.rating = nil

        self.ticket = nil
        self.travel = nil
        self.venue = nil
        self.setlistItems = []
    }
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

    @State private var draft: NewConcertVisit
    @State private var presentConfirmation: ConfirmationMessage? = nil

    @State private var openingTime = Date.now
    @State private var rating: Int = 0

    @State private var addSupportActPresenting = false
    @State private var selectArtistPresenting = false
    @State private var selectVenuePresenting = false
    @State private var createSetlistPresenting = false
    @State private var presentTicketEdit = false

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State var selectedImages: [UIImage] = []

    @FocusState private var noteEditorFocused
    @FocusState private var titleFocused

    @State private var savingConcertPresenting: Bool = false

    let possibleArtist: Artist?

    init(importedConcert: ImportedConcert? = nil, ticketInfo: ExtendedTicketInfo? = nil) {
        if let importedConcert {
            possibleArtist = importedConcert.artist
            draft = NewConcertVisit(importeConcert: importedConcert)
        } else if let ticketInfo {
            possibleArtist = ticketInfo.artist
            draft = NewConcertVisit(ticketInfo: ticketInfo)
        } else {
            draft = NewConcertVisit()
            possibleArtist = nil
        }
    }

    var body: some View {
        Group {
            if let artist = viewModel?.artist {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ArtistHeader(artist: artist)

                        timeSection()

                        supportActsSection()

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
                        HapticManager.shared.buttonTap()
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
        .frame(maxWidth: .infinity)
        .background {
            Color.background
                .ignoresSafeArea()
        }
        .task {
            guard viewModel == nil else { return }
            self.viewModel = CreateConcertVisitViewModel(artist: possibleArtist,
                                                         artistRepository: dependencies.artistRepository,
                                                         concertRepository: dependencies.concertRepository,
                                                         userSessionManager: dependencies.userSessionManager,
                                                         photoRepository: dependencies.photoRepository,
                                                         setlistRepository: dependencies.setlistRepository)
        }
        .adaptiveSheet(item: $presentConfirmation) { message in
            ConfirmationView(message: message)
                .interactiveDismissDisabled()
        }
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
        .sheet(isPresented: $addSupportActPresenting) {
            CreateConcertSelectArtistView(isPresented: $addSupportActPresenting, didSelectArtist: { artist in
                withAnimation {
                    self.addSupportActPresenting = false
                } completion: {
                    withAnimation {
                        draft.supportActs.append(artist)
                    }
                }
            })
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    HapticManager.shared.buttonTap()
                    noteEditorFocused = false
                    titleFocused = false
                } label: {
                    Text("Fertig")
                }
            }
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
        .showInterstitialAfterAction()
    }
    
    private func save() {
        Task {
            do {
                savingConcertPresenting = true

                // Konzert erstellen (wirft Error nur bei kritischen Fehlern)
                let response = try await viewModel?.createVisit(from: draft, selectedImages: selectedImages)

                // Konzerte neu laden
                try await dependencies.concertRepository.reloadConcerts()

                savingConcertPresenting = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfirmation(with: response)
                }
            } catch {
                savingConcertPresenting = false
                HapticManager.shared.error()

                // Hier nur kritische Fehler (Konzert konnte nicht erstellt werden)
                showErrorAlert(error: error)
            }
        }
    }

    private func showConfirmation(with response: CreationResponse?) {
        guard let response else { return }

        if response.success {
            // Alles perfekt gelaufen
            HapticManager.shared.success()
            presentConfirmation = ConfirmationMessage(message: "Konzert erfolgreich erstellt! 🎉") {
                navigationManager.popToRoot()
            }
        } else {
            // Konzert erstellt, aber mit Warnungen
            HapticManager.shared.success()

            let warningMessage = "Konzert erfolgreich erstellt! 🎉\nAber ein paar dinge sind leider schief gelaufen:"

            let additionalInfos = AdditionalInfo(infos: response.problems)
            presentConfirmation = ConfirmationMessage(message: warningMessage, additionalInfos: additionalInfos) {
                navigationManager.popToRoot()
            }
        }
    }

    private func showErrorAlert(error: Error) {
        presentConfirmation = ConfirmationMessage(
            message: "Konzert konnte nicht erstellt werden. Bitte versuche es später nochmal."
        )
    }

    @ViewBuilder
    func supportActsSection() -> some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Support Acts", image: nil)
                .padding(.horizontal)

            if !draft.supportActs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draft.supportActs) { artist in
                            ArtistChipView(artist: artist, removeable: true) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.supportActs.removeAll(where: { $0.id == artist.id })
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            Button {
                addSupportActPresenting = true
            } label: {
                Text("Spport Act hinzufügen")
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
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

            DatePicker("Einlass", selection: $openingTime, displayedComponents: [.hourAndMinute])
                .padding(.horizontal)
                .font(.cjBody)
                .onChange(of: openingTime) { _, newValue in
                    draft.openingTime = newValue
                }

            TextField("Titel (optional)", text: $draft.title)
                .focused($titleFocused)
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
                                HapticManager.shared.buttonTap()
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
                                    #warning("fix")
                                default:
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
                        HapticManager.shared.buttonTap()
                        presentTravelSection = true
                    } label: {
                        Text("Reiseinfos ändern")
                            .font(.cjBody)
                    }
                    .padding()
                    .glassEffect()
                } else {
                    Button {
                        HapticManager.shared.buttonTap()
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
                    
                    Text(ticket.ticketTypeEnum.label)
                        .font(.cjTitle)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    ticket.ticketCategoryEnum.color
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .overlay {
                            Text(ticket.ticketCategoryEnum.label)
                                .font(.cjTitleF)
                        }
                    
                    switch ticket.ticketTypeEnum {
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
                        HapticManager.shared.buttonTap()
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
                    HapticManager.shared.buttonTap()
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

            Stepper(value: $rating, in: 0...10) {
                HStack {
                    Text("Rating")
                        .font(.cjBody)
                    Spacer()
                    Text("\(rating)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .font(.cjBody)
                        .onChange(of: rating) { oldValue, newValue in
                            draft.rating = newValue
                        }
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
                        HapticManager.shared.buttonTap()
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
                        HapticManager.shared.buttonTap()
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
}
