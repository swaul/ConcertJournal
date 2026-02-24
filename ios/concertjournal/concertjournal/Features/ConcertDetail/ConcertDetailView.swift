//
//  ConcertDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 01.01.26.
//

import Combine
import SwiftUI
import Supabase
import EventKitUI
import SpotifyiOS

struct ConcertImage: Identifiable {
    let image: UIImage?
    let urlString: String?
    let id: String
    let index: Int

    var url: URL? {
        guard let urlString else { return nil }
        return URL(string: urlString)
    }
}

struct ConcertDetailView: View {
    @AppStorage("hidePrices") private var hidePrices = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State var viewModel: ConcertDetailViewModel? = nil
    @State private var confirmationTextPresenting: Bool = false

    let concert: Concert

    init(concert: Concert) {
        self.concert = concert
    }

    @State private var showCalendarSheet = false
    @State private var calendarEvent: EKEvent?
    @State private var confirmationText: ConfirmationMessage? = nil
    @State private var showEditSheet = false
    @State private var showDeleteDialog = false
    @State private var selectedImage: ConcertImage?
    @State private var savingConcertPresenting = false
    @State private var localHidePrices = false

    @State private var errorMessage: String? = nil

    let eventStore = EKEventStore()

    var body: some View {
        Group {
            if let viewModel {
                viewWithViewModel(viewModel: viewModel)
            } else {
                LoadingView()
            }
        }
        .task {
            viewModel = ConcertDetailViewModel(concert: concert,
                                               repository: dependencies.offlineConcertRepository,
                                               photoRepository: dependencies.offlinePhotoRepsitory)
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: ConcertDetailViewModel) -> some View {
        BannerAdContainer(position: .bottom) {
            ScrollView {
                ParallaxHeader(
                    coordinateSpace: CoordinateSpace.named("ScrollView"),
                    defaultHeight: 400
                ) {
                    AsyncImage(url: URL(string: viewModel.concert.artist.imageUrl ?? "")) { result in
                        result.image?
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .frame(height: 400)
                    .frame(maxWidth: UIScreen.screenWidth)
                }

                VStack(alignment: .leading, spacing: 24) {
                    header(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                        .zIndex(100)

                    if !viewModel.concert.supportActsArray.isEmpty {
                        supportActsSection(supportActs: viewModel.concert.supportActsArray)
                    }

                    if !viewModel.concert.buddiesArray.isEmpty {
                        buddiesSection(buddies: viewModel.concert.buddiesArray)
                    }
                    
                    if let venue = viewModel.concert.venue {
                        venueSection(venue: venue, viewModel: viewModel)
                    }

                    if let notes = viewModel.concert.notes, !notes.isEmpty {
                        notesSection(notes: notes)
                    }

                    if let travel = viewModel.concert.travel {
                        travelSection(travel: travel)
                    }

                    if let ticket = viewModel.concert.ticket {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "Mein Ticket", icon: "ticket.fill")
                            ticketSection(ticket: ticket)
                        }
                        .padding(.horizontal, 20)
                    }

                    if !viewModel.concert.setlistItemsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "Setlist", icon: "music.note.list")

                            VStack(spacing: 12) {
                                ForEach(viewModel.concert.setlistItemsArray, id: \.spotifyTrackId) { item in
                                    makeSetlistItemView(with: item)
                                }

                                if dependencies.userSessionManager.user?.identities?.contains(where: { $0.provider == "spotify" }) == true {
                                    CreatePlaylistButton(viewModel: viewModel)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if !viewModel.photos.isEmpty {
                        imageSection(images: viewModel.photos)
                    }

                    Color.clear.frame(height: 40)
                }
                .background {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(in: Rectangle())
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .coordinateSpace(name: CoordinateSpace.named("ScrollView"))
            .frame(width: UIScreen.screenWidth)
        }
        .ignoresSafeArea()
        .frame(width: UIScreen.screenWidth)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.concert.date > Date.now {
                    Button {
                        HapticManager.shared.impact(.light)
                        requestCalendarAccess()
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }

                Menu {
                    Button {
                        HapticManager.shared.impact(.light)
                        showEditSheet = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        HapticManager.shared.impact(.medium)
                        showDeleteDialog = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .adaptiveSheet(isPresented: $showDeleteDialog) {
            deleteDialog(viewModel: viewModel)
        }
        .adaptiveSheet(isPresented: $confirmationTextPresenting) {
            if let confirmationText {
                ConfirmationView(message: confirmationText, isPresented: $confirmationTextPresenting)
            }
        }
        .sheet(isPresented: $showCalendarSheet) {
            if let calendarEvent {
                EventEditView(
                    eventStore: eventStore,
                    event: calendarEvent
                ) { action in
                    if action == .saved {
                        HapticManager.shared.success()
                        confirmationText = ConfirmationMessage(message: "Event gespeichert 🎉")
                        confirmationTextPresenting = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ConcertEditView(
                concert: viewModel.concert,
                onSave: { updatedConcert in
                    Task {
                        savingConcertPresenting = true
                        await viewModel.applyUpdate(updatedConcert)

                        try? await Task.sleep(for: .seconds(2))
                        
                        savingConcertPresenting = false
                        HapticManager.shared.success()

                        try? await Task.sleep(for: .seconds(1))

                        confirmationText = ConfirmationMessage(message: "Updates gespeichert! 🎉")
                        confirmationTextPresenting = true
                    }
                }
            )
        }
        .adaptiveSheet(isPresented: $confirmationTextPresenting) {
            if let confirmationText {
                ConfirmationView(message: confirmationText, isPresented: $confirmationTextPresenting)
            }
        }
        .fullScreenCover(item: $selectedImage) { item in
            FullscreenImagePagerView(
                imageUrls: viewModel.photos,
                startIndex: item.index
            )
        }
        .sheet(isPresented: $savingConcertPresenting) {
            LoadingSheet(message: "Laden...")
        }
        .onAppear {
            localHidePrices = hidePrices
        }
        .onChange(of: localHidePrices) { _, newValue in
            hidePrices = newValue
        }
    }

    @ViewBuilder
    func deleteDialog(viewModel: ConcertDetailViewModel) -> some View {
        @State var loading: Bool = false

        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text(TextKey.concertDelete.localized)
                .font(.cjTitle)

            let concertText = viewModel.concert.title == nil ? "das Konzert" : "\"\(viewModel.concert.title!)\""
            Text(TextKey.deleteQuestion.localized(with: concertText))
                .font(.cjBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button(role: .destructive) {
                    HapticManager.shared.impact(.heavy)
                    Task {
                        do {
                            loading = true
                            try await viewModel.deleteConcert()
                            showDeleteDialog = false
                            loading = false
                            HapticManager.shared.success()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                confirmationText = ConfirmationMessage(message: TextKey.concertDeleted.localized) {
                                    dismiss()
                                }
                                confirmationTextPresenting = true
                            }
                        } catch {
                            logError("Deletion of concert failed", error: error, category: .concert)
                            loading = false
                        }
                    }
                } label: {
                    if loading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(TextKey.concertDelete.localized)
                            .font(.cjHeadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .cornerRadius(16)
                .disabled(loading)

                Button {
                    HapticManager.shared.impact(.light)
                    showDeleteDialog = false
                } label: {
                    Text(TextKey.cancel.localized)
                        .font(.cjHeadline)
                }
                .buttonStyle(ModernButtonStyle(style: .glass, color: dependencies.colorThemeManager.appTint))
            }
        }
        .padding(24)
    }

    // MARK: - Section Header
    @ViewBuilder
    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(dependencies.colorThemeManager.appTint)
            Text(title)
                .font(.cjTitle)
        }
    }

    @ViewBuilder
    func supportActsSection(supportActs: [Artist]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: TextKey.supportActs.localized, icon: "music.microphone")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(supportActs) { artist in
                        ArtistChipView(artist: artist, removeable: false, onRemove: {})
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
    
    @ViewBuilder
    func buddiesSection(buddies: [BuddyAttendee]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Dabei", icon: "person.2.fill")
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(buddies) { buddy in
                        VStack(spacing: 6) {
                            AvatarView(url: buddy.avatarURL, name: buddy.displayName, size: 64)
                            Text(buddy.displayName)
                                .font(.cjTitle2)
                                .foregroundStyle(dependencies.colorThemeManager.appTint)
                                .lineLimit(1)
                                .frame(maxWidth: 64)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Travel Info Card
    @ViewBuilder
    func travelInfoCard(icon: String, title: String, subtitle: String?, isPrice: Bool = false) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dependencies.colorThemeManager.appTint.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(dependencies.colorThemeManager.appTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.cjBody)
                    .foregroundStyle(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.cjTitle2)
                        .foregroundStyle(.primary)
                        .conditionalRedacted(isPrice && localHidePrices)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .contextMenu {
            if isPrice {
                Button {
                    HapticManager.shared.impact(.light)
                    localHidePrices.toggle()
                } label: {
                    Label(localHidePrices ? TextKey.showPrices.localized : TextKey.hidePrices.localized,
                          systemImage: localHidePrices ? "eye" : "eye.slash")
                }
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    func header(viewModel: ConcertDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Badge
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(viewModel.concert.date.dateOnlyString)
                    .font(.cjBody)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .shadow(radius: 3)
            .background(dependencies.colorThemeManager.appTint)
            .clipShape(Capsule())

            if let title = viewModel.concert.title {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)

                Button {
                    HapticManager.shared.impact(.light)
                    navigationManager.push(.artistDetail(viewModel.concert.artist))
                } label: {
                    HStack(spacing: 8) {
                        Text(viewModel.concert.artist.name)
                            .font(.cjTitle)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)

                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button {
                    HapticManager.shared.impact(.light)
                    navigationManager.push(.artistDetail(viewModel.concert.artist))
                } label: {
                    HStack(spacing: 8) {
                        Text(viewModel.concert.artist.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)

                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let openingTime = viewModel.concert.openingTime {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(TextKey.admission.localized + " " + openingTime.timeOnlyString)
                        .font(.cjHeadline)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
        .padding(.top, -40)
    }

    @ViewBuilder
    func venueSection(venue: Venue, viewModel: ConcertDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: TextKey.sectionLocation.localized, icon: "mappin.circle.fill")

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(venue.name)
                        .font(.cjTitle2)
                        .foregroundStyle(.primary)

                    Text(venue.formattedAddress)
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                if venue.latitude != 0, venue.longitude != 0 {
                    VenueInlineMap(latitude: venue.latitude, longitude: venue.longitude, name: venue.name, formattedAddress: venue.formattedAddress)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.ultraThinMaterial, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .contextMenu {
                            Button {
                                HapticManager.shared.impact(.light)
                                let mapItem = MKMapItem(location: CLLocation(latitude: venue.latitude, longitude: venue.longitude), address: MKAddress(fullAddress: "", shortAddress: venue.formattedAddress))
                                mapItem.openInMaps()
                            } label: {
                                Label("In Apple Karten öffnen", systemImage: "map.fill")
                            }
                            .font(.cjBody)
                        }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: TextKey.myExperience.localized, icon: "heart.text.square.fill")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(dependencies.colorThemeManager.appTint)
                    Text("ENTRY?")
                        .font(.cjCaption)
                        .foregroundStyle(dependencies.colorThemeManager.appTint)
                }

                Text(notes)
                    .font(.cjBody)
                    .lineLimit(nil)
                    .foregroundStyle(.primary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(dependencies.colorThemeManager.appTint.opacity(0.05))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(dependencies.colorThemeManager.appTint.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    func travelSection(travel: Travel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: TextKey.myTravel.localized, icon: "airplane.departure")

            VStack(spacing: 12) {
                if let travelType = travel.travelTypeEnum {
                    travelInfoCard(
                        icon: travelType.icon,
                        title: travelType.label,
                        subtitle: nil
                    )
                }

                if travel.travelDuration != 0 {
                    let parsedDuration = DurationParser.format(travel.travelDuration)
                    travelInfoCard(
                        icon: "clock.fill",
                        title: TextKey.travelTime.localized,
                        subtitle: parsedDuration
                    )
                }

                if travel.travelDistance != 0 {
                    let parsedDistance = DistanceParser.format(travel.travelDistance)
                    travelInfoCard(
                        icon: "location.fill",
                        title: TextKey.summaryDistance.localized,
                        subtitle: parsedDistance
                    )
                }

                if let travelExpenses = travel.travelExpenses {
                    travelInfoCard(
                        icon: "car.fill",
                        title: TextKey.arrivalCost.localized,
                        subtitle: travelExpenses.formatted,
                        isPrice: true
                    )
                }

                if let hotelExpenses = travel.hotelExpenses {
                    travelInfoCard(
                        icon: "bed.double.fill",
                        title: TextKey.hotel.localized,
                        subtitle: hotelExpenses.formatted,
                        isPrice: true
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Setlist Item
    @ViewBuilder
    func makeSetlistItemView(with item: SetlistItem) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            guard let spotifyTrackId = item.spotifyTrackId, !spotifyTrackId.isEmpty else { return }
            let url = "https://open.spotify.com/track/\(spotifyTrackId)"
            UIApplication.shared.open(URL(string: url)!)
        } label: {
            HStack(spacing: 16) {
                // Position Number
                ZStack {
                    Circle()
                        .fill(dependencies.colorThemeManager.appTint.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text("\(item.position + 1)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(dependencies.colorThemeManager.appTint)
                }

                // Cover Image
                AsyncImage(url: URL(string: item.coverImage ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 60, height: 60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Song Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.cjHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.artistNames)
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let albumName = item.albumName {
                        Text(albumName)
                            .font(.cjCaption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Spotify Icon
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(SetlistItemButtonStyle())
        .contextMenu {
            Button {
                HapticManager.shared.impact(.light)
                guard let spotifyTrackId = item.spotifyTrackId, !spotifyTrackId.isEmpty else { return }
                let url = "https://open.spotify.com/track/\(spotifyTrackId)"
                UIApplication.shared.open(URL(string: url)!)
            } label: {
                // TODO: LOCALIZATION
                Label("\(item.title) in Spotify abspielen", systemImage: "play.circle.fill")
            }
            .font(.cjBody)
        }
    }

    // MARK: - Ticket Section
    @ViewBuilder
    func ticketSection(ticket: Ticket) -> some View {
        if let ticketCategory = ticket.ticketCategoryEnum, let ticketType = ticket.ticketTypeEnum {
            VStack(spacing: 16) {
                // Ticket Type Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: ticketType.icon)
                            .font(.title2)
                        Text(ticketType.label)
                            .font(.cjTitle)
                    }
                    .foregroundStyle(.white)

                    Text(ticketCategory.label)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [
                                ticketCategory.color,
                                ticketCategory.color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Decorative circles
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .offset(x: -50, y: -30)

                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .offset(x: 70, y: 40)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: ticketCategory.color.opacity(0.4), radius: 12, x: 0, y: 6)

                // Seat Information
                switch ticketType {
                case .seated:
                    HStack(spacing: 12) {
                        if let block = ticket.seatBlock {
                            seatInfoBox(title: TextKey.block.localized, value: block)
                        }
                        if let row = ticket.seatRow {
                            seatInfoBox(title: TextKey.row.localized, value: row)
                        }
                        if let seatNumber = ticket.seatNumber {
                            seatInfoBox(title: TextKey.seat.localized, value: seatNumber)
                        }
                    }
                case .standing:
                    if let standingPosition = ticket.standingPosition {
                        VStack(spacing: 8) {
                            Text(TextKey.position.localized)
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                            Text(standingPosition)
                                .font(.cjTitle2)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                // Ticket Price
                if let ticketPrice = ticket.ticketPrice {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(dependencies.colorThemeManager.appTint.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: "eurosign.circle.fill")
                                .font(.title3)
                                .foregroundStyle(dependencies.colorThemeManager.appTint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(TextKey.price.localized)
                                .font(.cjBody)
                                .foregroundStyle(.secondary)

                            Text(ticketPrice.formatted)
                                .font(.cjTitle)
                                .foregroundStyle(.primary)
                                .conditionalRedacted(localHidePrices)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            HapticManager.shared.impact(.light)
                            localHidePrices.toggle()
                        } label: {
                            Label(localHidePrices ? TextKey.showPrices.localized : TextKey.hidePrices.localized,
                                  systemImage: localHidePrices ? "eye" : "eye.slash")
                        }
                    }
                }

                // Ticket Notes
                if let notes = ticket.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.caption)
                            Text(TextKey.notes.localized)
                                .font(.cjCaption)
                        }
                        .foregroundStyle(.secondary)

                        Text(notes)
                            .font(.cjBody)
                            .foregroundStyle(.primary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    @ViewBuilder
    func imageSection(images: [ConcertImage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: TextKey.photo.localized, icon: "photo.on.rectangle.angled")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(images), id: \.id) { image in
                        Button {
                            HapticManager.shared.impact(.light)
                            selectedImage = image
                        } label: {
                            if let localImage = image.image {
                                // ✅ Instant: from disk, no network
                                Image(uiImage: localImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 240, height: 320)
                                    .clipped()
                            } else if let serverUrl = image.url {
                                // ⬆️ Uploaded: load from server
                                AsyncImage(url: serverUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 240, height: 320)
                                            .clipped()
                                    case .failure:
                                        photoPlaceholder(icon: "exclamationmark.triangle")
                                    case .empty:
                                        photoPlaceholder(icon: "photo")
                                            .overlay { ProgressView() }
                                    @unknown default:
                                        photoPlaceholder(icon: "photo")
                                    }
                                }
                            } else {
                                // Broken state
                                photoPlaceholder(icon: "photo")
                            }
                        }
                        .buttonStyle(ImageCardButtonStyle())
                        .frame(width: 240, height: 320)
                        .scrollTargetLayout()
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func photoPlaceholder(icon: String) -> some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    func seatInfoBox(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.cjCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.cjTitle)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func requestCalendarAccess() {
        Task {
            do {
                guard try await eventStore.requestWriteOnlyAccessToEvents() else { return }
                calendarEvent = viewModel?.createCalendarEntry(store: eventStore)
                showCalendarSheet = true
            } catch {
                print("could not open calendar thingy. Reason:", error)
            }
        }
    }
}

// MARK: - Button Styles

struct SetlistItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ImageCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension Date {
    var dateOnlyString: String {
        self.formatted(
            Date.FormatStyle()
                .year()
                .month(.wide)
                .day()
                .locale(Locale(identifier: "de_DE"))
        )
    }

    var timeOnlyString: String {
        self.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .abbreviated))
                .minute(.twoDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }

    var shortDateOnlyString: String {
        self.formatted(
            Date.FormatStyle()
                .year(.twoDigits)
                .month(.abbreviated)
                .day(.twoDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
}

extension TicketType {
    var icon: String {
        switch self {
        case .seated:
            return "chair.fill"
        case .standing:
            return "figure.stand"
        }
    }
}

extension TravelType {
    var icon: String {
        switch self {
        case .car:
            return "car.fill"
        case .train:
            return "tram.fill"
        case .plane:
            return "airplane"
        case .bus:
            return "bus.fill"
        case .bike:
            return "bicycle"
        case .foot:
            return "figure.walk"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}

import MapKit
import SwiftUI

struct VenueInlineMap: View {
    let latitude: Double
    let longitude: Double
    let name: String
    let formattedAddress: String

    @State private var position: MapCameraPosition

    init(latitude: Double, longitude: Double, name: String, formattedAddress: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.formattedAddress = formattedAddress

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
        )
    }

    var body: some View {
        Map(position: $position) {
            Marker(name, coordinate: CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            ))
        }
        .mapStyle(.imagery)
        .allowsHitTesting(false)
    }
}

struct EventEditView: UIViewControllerRepresentable {
    let eventStore: EKEventStore
    let event: EKEvent
    let onComplete: (EKEventEditViewAction) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.eventStore = eventStore
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onComplete: (EKEventEditViewAction) -> Void

        init(onComplete: @escaping (EKEventEditViewAction) -> Void) {
            self.onComplete = onComplete
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            controller.dismiss(animated: true)
            onComplete(action)
        }
    }
}

extension AttributedString {
    mutating func applyBaseFont(_ font: Font = .cjBody) {
        self.font = font
    }

    mutating func highlight(
        _ text: String,
        color: Color,
        font: Font = .cjBody
    ) {
        if let range = range(of: text) {
            self[range].foregroundColor = color
            self[range].font = font
        }
    }
}

extension Text {
    static func highlighted(
        _ text: String,
        highlight: String,
        baseFont: Font = .cjBody,
        highlightColor: Color,
        highlightFont: Font = .cjHeadline
    ) -> Text {
        var attributed = AttributedString(text)
        attributed.font = baseFont

        if let range = attributed.range(of: highlight) {
            attributed[range].foregroundColor = highlightColor
            attributed[range].font = highlightFont
        }

        return Text(attributed)
    }
}

extension View {
    @ViewBuilder
    func conditionalRedacted(_ shouldRedact: Bool) -> some View {
        if shouldRedact {
            self.redacted(reason: .placeholder)
        } else {
            self
        }
    }
}
