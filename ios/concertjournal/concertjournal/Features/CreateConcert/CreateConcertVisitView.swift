import Combine
import CoreData
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

    var tourName: String? = nil
    var tour: NSManagedObjectID? = nil
    var artist: ArtistDTO? = nil
    var supportActs: [ArtistDTO] = []
    var ticket: TicketDTO? = nil
    var travel: TravelDTO? = nil
    var venue: VenueDTO? = nil
    var setlistItems: [TempCeateSetlistItem] = []
    var buddyAttendees: [BuddyAttendee] = []

    init(importeConcert: ImportedConcert) {
        self.date = importeConcert.date ?? .now
        self.openingTime = importeConcert.date ?? .now
        self.artistName = importeConcert.artistName ?? ""
        self.venueName = importeConcert.venueName ?? ""
        self.title = importeConcert.title ?? ""
        self.notes = importeConcert.notes ?? ""
        self.rating = 0

        self.tour = nil
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

        self.tour = nil
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

        self.tour = nil
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

// MARK: - Sheet State

@Observable
class ConcertSheetState {
    var selectArtist = false
    var selectVenue = false
    var selectTour = false
    var addSupportAct = false
    var createSetlist = false
    var editTicket = false
    var selectBuddies = false
    var travel = false
    var savingConcert = false
    var confirmCancel = false
    var playlistPicker = false
    var confirmation: ConfirmationMessage? = nil
    var confirmationPresenting = false
    var error: ErrorMessage? = nil
    var errorPresenting = false
}

// MARK: - Main View

struct CreateConcertVisitView: View {

    @Environment(\.navigationManager) private var navigationManager
    @Environment(\.dependencies) private var dependencies

    @State var viewModel: CreateConcertVisitViewModel?
    @State var draft: NewConcertVisit
    @State var sheets = ConcertSheetState()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedImages: [UIImage] = []
    @State private var rating: Int = 0
    @State private var openingTime = Date.now

    @FocusState private var noteEditorFocused
    @FocusState private var titleFocused

    let possibleArtist: ArtistDTO?

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
                concertForm(artist: artist)
            } else {
                selectArtistPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.background.ignoresSafeArea())
        .task {
            guard viewModel == nil else { return }
            viewModel = CreateConcertVisitViewModel(
                artist: possibleArtist,
                repository: dependencies.offlineConcertRepository,
                photoRepository: dependencies.offlinePhotoRepsitory,
                notificationService: dependencies.buddyNotificationService
            )
        }
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .applySheets(
            sheets: sheets,
            draft: $draft,
            viewModel: viewModel,
            selectedImages: selectedImages,
            onSave: save,
            onDismiss: { navigationManager.pop() }
        )
        .showInterstitialAfterAction()
    }

    // MARK: - Subviews

    private var selectArtistPlaceholder: some View {
        VStack(alignment: .leading) {
            Spacer()
            Button {
                HapticManager.shared.buttonTap()
                sheets.selectArtist = true
            } label: {
                Text(TextKey.selectArtist.localized)
                    .font(.cjBody)
            }
            .buttonStyle(.glassProminent)
            .padding(.bottom, 32)
        }
        .onAppear { sheets.selectArtist = true }
    }

    private func concertForm(artist: ArtistDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ArtistHeader(artist: artist)
                ConcertTimeSection(draft: $draft, openingTime: $openingTime, titleFocused: $titleFocused)
                ConcertTourSection(draft: $draft, onSelect: { sheets.selectTour = true })
                ConcertSupportActsSection(draft: $draft, onAdd: { sheets.addSupportAct = true })
                ConcertVenueSection(draft: $draft, onSelect: { sheets.selectVenue = true })
                ConcertTravelSection(draft: $draft, onEdit: { sheets.travel = true })
                ConcertTicketSection(draft: $draft, onEdit: { sheets.editTicket = true })
                ConcertBuddySection(draft: $draft, onSelect: { sheets.selectBuddies = true })
                ConcertRatingSection(rating: $rating, draft: $draft)
                ConcertNoteSection(draft: $draft, focused: $noteEditorFocused)
                ConcertSetlistSection(
                    draft: $draft,
                    onCreateSetlist: { sheets.createSetlist = true },
                    onImportPlaylist: { sheets.playlistPicker = true },
                    onParsePlaylist: parsePlaylistToSetlist
                )
                ConcertImagesSection(
                    draft: $draft,
                    selectedPhotoItems: $selectedPhotoItems,
                    selectedImages: $selectedImages
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    HapticManager.shared.buttonTap()
                    noteEditorFocused = false
                    titleFocused = false
                } label: {
                    Text(TextKey.done.localized)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                sheets.confirmCancel = true
            }
            .font(.cjBody)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .font(.cjBody)
        }
    }

    // MARK: - Actions

    private func save() {
        guard let viewModel else { return }
        Task {
            do {
                sheets.savingConcert = true
                try await viewModel.createVisit(from: draft, selectedImages: selectedImages)
                try? await Task.sleep(for: .seconds(2))
                sheets.savingConcert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    HapticManager.shared.success()
                    sheets.confirmation = ConfirmationMessage(message: TextKey.concertCreated.localized) {
                        navigationManager.popToRoot()
                    }
                    sheets.confirmationPresenting = true
                }
            } catch {
                sheets.savingConcert = false
                HapticManager.shared.error()
                sheets.error = ErrorMessage(message: TextKey.concertCreate.localized)
                sheets.errorPresenting = true
            }
        }
    }

    private func parsePlaylistToSetlist(_ playlist: SpotifyPlaylist) {
        Task {
            try await dependencies.userSessionManager.refreshSpotifyProviderTokenIfNeeded()
            guard dependencies.userSessionManager.providerToken != nil else { return }
            do {
                draft.setlistItems = try await dependencies.spotifyRepository.importPlaylistToSetlist(playlistId: playlist.id)
            } catch {
                logError("Failed to import playlist", error: error)
            }
        }
    }
}

// MARK: - Sheet Modifier

private struct ConcertSheetsModifier: ViewModifier {

    @Environment(\.dependencies) private var dependencies

    @Bindable var sheets: ConcertSheetState
    @Binding var draft: NewConcertVisit
    var viewModel: CreateConcertVisitViewModel?
    var selectedImages: [UIImage]
    var onSave: () -> Void
    var onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .adaptiveSheet(isPresented: $sheets.confirmationPresenting) {
                if let msg = sheets.confirmation {
                    ConfirmationView(message: msg, isPresented: $sheets.confirmationPresenting)
                }
            }
            .adaptiveSheet(isPresented: $sheets.errorPresenting) {
                if let err = sheets.error {
                    ErrorSheetView(message: err, isPresented: $sheets.errorPresenting)
                        .interactiveDismissDisabled()
                }
            }
            .adaptiveSheet(isPresented: $sheets.confirmCancel) {
                CancelConcertConfirmationView {
                    sheets.confirmCancel = false
                    onDismiss()
                } onContinue: {
                    sheets.confirmCancel = false
                }
            }
            .sheet(isPresented: $sheets.createSetlist) {
                CreateSetlistView(
                    viewModel: CreateSetlistViewModel(
                        currentSelection: draft.setlistItems,
                        artist: viewModel?.artist,
                        spotifyRepository: dependencies.spotifyRepository,
                        setlistRepository: dependencies.setlistRepository
                    )
                ) { setlistItems in
                    draft.setlistItems = setlistItems
                    sheets.createSetlist = false
                }
            }
            .sheet(isPresented: $sheets.addSupportAct) {
                CreateConcertSelectArtistView(isPresented: $sheets.addSupportAct) { artist in
                    withAnimation { sheets.addSupportAct = false } completion: {
                        withAnimation { draft.supportActs.append(artist) }
                    }
                }
            }
            .sheet(isPresented: $sheets.selectArtist) {
                CreateConcertSelectArtistView(isPresented: $sheets.selectArtist) { artist in
                    withAnimation { sheets.selectArtist = false } completion: {
                        withAnimation {
                            draft.artist = artist
                            draft.artistName = artist.name
                            viewModel?.artist = artist
                        }
                    }
                }
            }
            .sheet(isPresented: $sheets.selectVenue) {
                CreateConcertSelectVenueView(isPresented: $sheets.selectVenue) { venue in
                    draft.venueName = venue.name
                    draft.venue = venue
                }
            }
            .sheet(isPresented: $sheets.selectTour) {
                SelectTourView { tour in
                    draft.tour = tour.objectID
                    draft.tourName = tour.name
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $sheets.selectBuddies) {
                BuddyAttendeePickerSheet(
                    selectedAttendees: draft.buddyAttendees,
                    isPresented: $sheets.selectBuddies
                ) { buddies in
                    draft.buddyAttendees = buddies
                }
            }
            .sheet(isPresented: $sheets.editTicket) {
                CreateConcertTicket(artist: viewModel?.artist) { ticketInfo in
                    draft.ticket = ticketInfo
                    sheets.editTicket = false
                }
            }
            .sheet(isPresented: $sheets.savingConcert) {
                ZStack {
                    VStack {
                        ProgressView()
                            .tint(dependencies.colorThemeManager.appTint)
                        Text(TextKey.save.localized)
                            .font(.cjBody)
                    }
                }
                .frame(height: 250)
                .presentationDetents([.height(250)])
                .interactiveDismissDisabled()
            }
    }
}

private extension View {
    func applySheets(
        sheets: ConcertSheetState,
        draft: Binding<NewConcertVisit>,
        viewModel: CreateConcertVisitViewModel?,
        selectedImages: [UIImage],
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(ConcertSheetsModifier(
            sheets: sheets,
            draft: draft,
            viewModel: viewModel,
            selectedImages: selectedImages,
            onSave: onSave,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Section Views

struct ConcertTimeSection: View {
    @Binding var draft: NewConcertVisit
    @Binding var openingTime: Date
    var titleFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.times.localized, image: nil)
                .padding(.horizontal)
            DatePicker(TextKey.date.localized, selection: $draft.date, displayedComponents: [.date])
                .padding(.horizontal)
                .font(.cjBody)
            DatePicker(TextKey.admission.localized, selection: $openingTime, displayedComponents: [.hourAndMinute])
                .padding(.horizontal)
                .font(.cjBody)
                .onChange(of: openingTime) { _, newValue in
                    draft.openingTime = newValue
                }
            TextField(TextKey.titleOptional.localized, text: $draft.title)
                .focused(titleFocused)
                .textInputAutocapitalization(.words)
                .font(.cjBody)
                .padding()
                .glassEffect()
                .padding()
        }
    }
}

struct ConcertTourSection: View {
    @Binding var draft: NewConcertVisit

    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Tour", image: nil)
                .padding(.horizontal)

            if let artist = draft.artist, let tourName = draft.tourName {
                Text("\(artist.name): \(tourName)")
                    .font(.cjTitleF)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .glassEffect()
            }

            Button {
                onSelect()
            } label: {
                Text("Tour hinzufügen")
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }
}

struct ConcertSupportActsSection: View {
    @Binding var draft: NewConcertVisit
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.supportActs.localized, image: nil)
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
                onAdd()
            } label: {
                Text(TextKey.addSupportAct.localized)
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }
}

struct ConcertVenueSection: View {
    @Binding var draft: NewConcertVisit
    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.sectionLocation.localized, image: nil)
                .padding(.horizontal)
            if !draft.venueName.isEmpty {
                VStack(alignment: .leading) {
                    Text(draft.venueName).font(.cjBody)
                    if let city = draft.venue?.city {
                        Text(city).font(.cjBody)
                    }
                }
                .padding()
            }
            Button {
                onSelect()
            } label: {
                Text(TextKey.selectVenue.localized).font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }
}

struct ConcertTravelSection: View {
    @Binding var draft: NewConcertVisit
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.travel.localized, image: nil)
                .padding(.horizontal)

            if let travel = draft.travel {
                VStack(alignment: .leading, spacing: 8) {
                    if let travelType = travel.travelType {
                        travelTypeLabel(travelType)
                    }
                    if let duration = travel.travelDuration {
                        Text(TextKey.durationWas.localized(with: DurationParser.format(duration))).font(.cjBody)
                    }
                    if let distance = travel.travelDistance {
                        Text(TextKey.distanceWas.localized(with: DistanceParser.format(distance))).font(.cjBody)
                    }
                    if let expenses = travel.travelExpenses {
                        Text(TextKey.costWas.localized(with: expenses.formatted)).font(.cjBody)
                    }
                    if let hotel = travel.hotelExpenses {
                        Text(TextKey.hotelCost.localized(with: hotel.formatted)).font(.cjBody)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                .padding(.horizontal)
            }

            Button {
                HapticManager.shared.buttonTap()
                onEdit()
            } label: {
                Text(draft.travel == nil ? TextKey.addTravelInfo.localized : TextKey.changeTravelInfo.localized)
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func travelTypeLabel(_ type: TravelType) -> some View {
        switch type {
        case .car:   Text(TextKey.modeCar.localized).font(.cjBody)
        case .plane: Text(TextKey.modePlane.localized).font(.cjBody)
        case .bike:  Text(TextKey.modeBike.localized).font(.cjBody)
        case .foot:  Text(TextKey.modeWalking.localized).font(.cjBody)
        default:     Text(TextKey.modeTrain.localized).font(.cjBody)
        }
    }
}

struct ConcertTicketSection: View {
    @Binding var draft: NewConcertVisit
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.ticket.localized, image: nil)
                .padding(.horizontal)
            if let ticket = draft.ticket {
                ticketDetails(ticket)
            }
            Button {
                HapticManager.shared.buttonTap()
                onEdit()
            } label: {
                Text(TextKey.infoAdd.localized).font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func ticketDetails(_ ticket: TicketDTO) -> some View {
        VStack(alignment: .leading) {
            Text(ticket.ticketType.label)
                .font(.cjTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            ticket.ticketCategory.color
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity, idealHeight: 80)
                .overlay { Text(ticket.ticketCategory.label).font(.cjTitleF) }
                .padding(.horizontal)

            switch ticket.ticketType {
            case .seated:
                Grid {
                    GridRow {
                        if ticket.seatBlock != nil { Text(TextKey.block.localized).font(.cjHeadline) }
                        if ticket.seatRow != nil   { Text(TextKey.row.localized).font(.cjHeadline) }
                        if ticket.seatNumber != nil { Text(TextKey.seat.localized).font(.cjHeadline) }
                    }
                    GridRow {
                        if let b = ticket.seatBlock  { Text(b).font(.cjTitle) }
                        if let r = ticket.seatRow    { Text(r).font(.cjTitle) }
                        if let s = ticket.seatNumber { Text(s).font(.cjTitle) }
                    }
                }
            case .standing:
                if let pos = ticket.standingPosition {
                    Text(pos).font(.cjBody)
                }
            }

            if let notes = ticket.notes {
                Text(notes).font(.cjBody).padding(.horizontal)
            }
        }
    }
}

struct ConcertBuddySection: View {
    @Binding var draft: NewConcertVisit
    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: "Mit dabei", image: nil)
                .padding(.horizontal)

            if !draft.buddyAttendees.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draft.buddyAttendees) { attendee in
                            AttendeeChip(attendee: attendee) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.buddyAttendees.removeAll { $0.id == attendee.id }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            Button {
                HapticManager.shared.buttonTap()
                onSelect()
            } label: {
                Label(
                    draft.buddyAttendees.isEmpty ? "Begleiter hinzufügen" : "Begleiter bearbeiten",
                    systemImage: "person.badge.plus"
                )
                .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
        }
    }
}

struct ConcertRatingSection: View {
    @Binding var rating: Int
    @Binding var draft: NewConcertVisit

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.sectionRating.localized, image: nil)
                .padding(.horizontal)
            Stepper(value: $rating, in: 0...10) {
                HStack {
                    Text(TextKey.fieldRating.localized).font(.cjBody)
                    Spacer()
                    Text("\(rating)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .font(.cjBody)
                }
            }
            .padding(.horizontal)
            .onChange(of: rating) { _, newValue in
                draft.rating = newValue
            }
        }
    }
}

struct ConcertNoteSection: View {
    @Binding var draft: NewConcertVisit
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.myExperience.localized, image: nil)
                .padding(.horizontal)
            TextEditor(text: $draft.notes)
                .background(Color.clear)
                .focused(focused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding()
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                .padding(.horizontal)
                .font(.cjBody)
        }
    }
}

struct ConcertSetlistSection: View {
    @Environment(\.dependencies) private var dependencies
    @Binding var draft: NewConcertVisit
    var onCreateSetlist: () -> Void
    var onImportPlaylist: () -> Void
    var onParsePlaylist: (SpotifyPlaylist) -> Void

    private var isSpotifyLinked: Bool {
        dependencies.userSessionManager.user?.identities?.contains(where: { $0.provider == "spotify" }) == true
    }

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.setlist.localized, image: nil)
                .padding(.horizontal)

            if !draft.setlistItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(draft.setlistItems, id: \.id) { item in
                        SetlistItemRow(item: item)
                    }
                    Button {
                        HapticManager.shared.buttonTap()
                        onCreateSetlist()
                    } label: {
                        Text(TextKey.editSetlist.localized)
                            .padding()
                            .glassEffect()
                            .font(.cjBody)
                    }
                }
                .padding(.horizontal)
            } else {
                Button {
                    onCreateSetlist()
                } label: {
                    Text(TextKey.addSetlist.localized)
                        .padding()
                        .glassEffect()
                        .font(.cjBody)
                }
                .padding(.horizontal)

                if isSpotifyLinked {
                    Button {
                        HapticManager.shared.buttonTap()
                        onImportPlaylist()
                    } label: {
                        HStack {
                            Image("Spotify")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 38)
                            Text(TextKey.importFromSpotify.localized)
                                .font(.cjBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(6)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct SetlistItemRow: View {
    let item: TempCeateSetlistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.albumName ?? " ")
                .font(.cjCaption)
                .padding(.leading)
                .padding(.top)

            HStack {
                AsyncImage(url: URL(string: item.coverImage ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .padding(.leading)

                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.cjBody)
                        .bold()
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.artistNames)
                        .font(.cjBody)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing)
            }
            .padding(.bottom)
        }
        .rectangleGlass()
    }
}

struct ConcertImagesSection: View {
    @Binding var draft: NewConcertVisit
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var selectedImages: [UIImage]

    var body: some View {
        VStack(alignment: .leading) {
            CJDivider(title: TextKey.images.localized, image: nil)
                .padding(.horizontal)

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 5,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(TextKey.addPhotos.localized, systemImage: "photo.on.rectangle.angled")
                    .font(.cjBody)
            }
            .padding()
            .buttonStyle(.glass)
            .padding(.horizontal)
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task { await loadSelectedImages(from: newItems) }
            }

            if !selectedImages.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 3),
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
                                selectedImages.remove(at: index)
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

    @MainActor
    private func loadSelectedImages(from items: [PhotosPickerItem]) async {
        selectedImages.removeAll()
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }
}
