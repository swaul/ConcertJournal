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
    let url: URL
    let id: String
    let index: Int
}

struct ConcertDetailView: View {
    @AppStorage("hidePrices") private var hidePrices = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State var viewModel: ConcertDetailViewModel?

    let concert: FullConcertVisit
    
    @State private var showCalendarSheet = false
    @State private var calendarEvent: EKEvent?
    @State private var confirmationText: ConfirmationMessage? = nil
    @State private var showEditSheet = false
    @State private var showDeleteDialog = false
    @State private var selectedImage: ConcertImage?
 
    @State private var savingConcertPresenting = false
    
    @State private var loadingSetlist = false

    @State private var localHidePrices = false

    let eventStore = EKEventStore()
    
    var body: some View {
        Group {
            if let viewModel {
                viewWithViewModel(viewModel: viewModel)
                    .onChange(of: viewModel.loadingSetlist) { _, newValue in
                        withAnimation(.bouncy) {
                            loadingSetlist = newValue
                        }
                    }
            } else {
                LoadingView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = ConcertDetailViewModel(concert: concert,
                                               bffClient: dependencies.bffClient,
                                               concertRepository: dependencies.concertRepository,
                                               setlistRepository: dependencies.setlistRepository,
                                               photoRepository: dependencies.photoRepository)
        }

    }

    @ViewBuilder
    func viewWithViewModel(viewModel: ConcertDetailViewModel) -> some View {
        GeometryReader { reader in
            ZStack {
                background(reader: reader, viewModel: viewModel)

                ScrollView {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.concert.date.dateOnlyString)
                                .font(.cjTitle2)

                            if let title = viewModel.concert.title {
                                Text(title)
                                    .bold()
                                    .font(.cjLargeTitle)
                            } else {
                                Text(viewModel.artist.name)
                                    .bold()
                                    .font(.cjLargeTitle)
                            }
                        }
                        .padding()
                        .rectangleGlass()
                        .padding(.horizontal)

                        if let venue = viewModel.concert.venue {
                            Text("Location")
                                .font(.cjTitle)
                                .padding(.horizontal)

                            VStack(alignment: .leading) {
                                Text(venue.name)
                                    .bold()
                                    .font(.cjBody)

                                Text(venue.formattedAddress)
                                    .font(.cjBody)

                                if let latitude = venue.latitude, let longitude = venue.longitude {
                                    VenueInlineMap(latitude: latitude, longitude: longitude, name: venue.name)
                                }
                            }
                            .padding()
                            .rectangleGlass()
                            .padding(.horizontal)
                        }

                        if let notes = viewModel.concert.notes {
                            Text("Meine Experience")
                                .font(.cjTitle)
                                .padding(.horizontal)

                            VStack(alignment: .leading) {
                                HStack(alignment: .center) {
                                    Image(systemName: "long.text.page.and.pencil")
                                        .foregroundStyle(dependencies.colorThemeManager.appTint)
                                        .font(.cjCaption)
                                    Text("Journal Eintrag")
                                        .foregroundStyle(dependencies.colorThemeManager.appTint)
                                        .font(.cjCaption)
                                    Spacer()
                                }
                                .padding(.top)
                                .padding(.horizontal)

                                Text(notes)
                                    .lineLimit(nil)
                                    .padding(.bottom)
                                    .padding(.horizontal)
                                    .font(.cjBody)
                            }
                            .rectangleGlass()
                            .padding(.horizontal)
                        }
                        
                        if let travel = viewModel.concert.travel {
                            Text("Meine Reise")
                                .font(.cjTitle)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                
                                if let travelType = travel.travelType {
                                    Text(travelType.infoText(color: dependencies.colorThemeManager.appTint))
                                }
                                if let travelDuration = travel.travelDuration {
                                    let parsedDuration = DurationParser.format(travelDuration)

                                    Text.highlighted(
                                        "Die Reise hat \(parsedDuration) gedauert.",
                                        highlight: parsedDuration,
                                        baseFont: .cjBody,
                                        highlightColor: dependencies.colorThemeManager.appTint
                                    )
                                }
                                if let travelDistance = travel.travelDistance {
                                    let parsedDistance = DistanceParser.format(travelDistance)
                                    
                                    Text.highlighted(
                                        "Der Weg war \(parsedDistance) lang.",
                                        highlight: parsedDistance,
                                        baseFont: .cjBody,
                                        highlightColor: dependencies.colorThemeManager.appTint
                                    )
                                }
                                if let travelExpenses = travel.travelExpenses {
                                    Text.highlighted(
                                        "Die Anreise hat dich \(travelExpenses.formatted) gekostet.",
                                        highlight: travelExpenses.formatted,
                                        baseFont: .cjBody,
                                        highlightColor: dependencies.colorThemeManager.appTint
                                    )
                                    .conditionalRedacted(localHidePrices)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Toggle("Preise ausblenden", isOn: $localHidePrices)
                                    }
                                }
                                if let hotelExpenses = travel.hotelExpenses {
                                    Text.highlighted(
                                        "Für die Übernachtung hast du \(hotelExpenses.formatted) gezahlt.",
                                        highlight: hotelExpenses.formatted,
                                        baseFont: .cjBody,
                                        highlightColor: dependencies.colorThemeManager.appTint
                                    )
                                    .conditionalRedacted(localHidePrices)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Toggle("Preise ausblenden", isOn: $localHidePrices)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                            .padding(.horizontal)
                        }

                        if let ticket = viewModel.concert.ticket {
                            Text("Mein Ticket")
                                .font(.cjTitle)
                                .padding(.horizontal)

                            ticketSection(ticket: ticket)
                                .padding(.horizontal)
                        }

                        if let setlistItems = viewModel.setlistItems, !setlistItems.isEmpty {
                            Text("Setlist")
                                .font(.cjTitle)
                                .padding(.horizontal)
                            
                            VStack {
                                ForEach(setlistItems, id: \.spotifyTrackId) { item in
                                    makeSetlistItemView(with: item)
                                }
                                
                                
                                if dependencies.userSessionManager.user?.identities?.contains(where: { $0.provider == "spotify" }) == true {
                                    CreatePlaylistButton(viewModel: viewModel)
                                        .padding(.horizontal)
                                }
                            }
                            .padding()
                            .rectangleGlass()
                            .padding(.horizontal)
                        } else if loadingSetlist {
                            VStack {
                                ProgressView()
                                    .tint(dependencies.colorThemeManager.appTint)
                            }
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                        }

                        if !viewModel.imageUrls.isEmpty {
                            Text("Meine Bilder")
                                .font(.cjTitle)
                                .padding(.horizontal)

                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 16) {
                                    ForEach(Array(viewModel.imageUrls), id: \.id) { image in
                                        Button {
                                            selectedImage = image
                                        } label: {
                                            AsyncImage(url: image.url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 200, height: 300)
                                                    .clipped()
                                                    .cornerRadius(20)
                                            } placeholder: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .fill(Color.gray.opacity(0.3))
                                                    ProgressView()
                                                }
                                                .frame(width: 200, height: 300)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 200, height: 300)
                                        .scrollTargetLayout()
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .scrollClipDisabled()
                            .scrollTargetBehavior(.viewAligned)
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(width: reader.size.width)
                .safeAreaInset(edge: .top) {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 200)
                }
            }
            .frame(width: reader.size.width)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.concert.date > Date.now {
                    Button {
                        requestCalendarAccess()
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }

                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Bearbeiten")
                        }
                    }
                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Löschen")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .confirmationDialog("Konzert löschen", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteConcert()
                        confirmationText = ConfirmationMessage(message: "Konzert gelöscht!") {
                            dismiss()
                        }
                    } catch {
                        print(error)
                    }
                }
            } label: {
                Text("Löschen")
            }
            Button {

            } label: {
                Text("Abbrechen")
            }
        }
        .sheet(isPresented: $showCalendarSheet) {
            if let calendarEvent {
                EventEditView(
                    eventStore: eventStore,
                    event: calendarEvent
                ) { action in
                    if action == .saved {
                        confirmationText = ConfirmationMessage(message: "Event gespeichert 🎉")
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
                        savingConcertPresenting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            confirmationText = ConfirmationMessage(message: "Updates gespeichert!")
                        }
                    }
                }
            )
        }
        .sheet(item: $confirmationText) { item in
            ConfirmationView(message: item)
        }
        .fullScreenCover(item: $selectedImage) { item in
            FullscreenImagePagerView(
                imageUrls: viewModel.imageUrls,
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
    func background(reader: GeometryProxy, viewModel: ConcertDetailViewModel) -> some View {
        VStack {
            ConcertBackgroundImage(width: reader.size.width, imageUrl: viewModel.artist.imageUrl ?? "")
                .edgesIgnoringSafeArea(.top)

            Spacer()
        }
        .frame(width: reader.size.width)
        .edgesIgnoringSafeArea(.top)
    }

    @ViewBuilder
    func makeSetlistItemView(with item: SetlistItem) -> some View {
        Button {
            guard let spotifyTrackId = item.spotifyTrackId, !spotifyTrackId.isEmpty else { return }
            let url = "https://open.spotify.com/track/\(spotifyTrackId)"
            UIApplication.shared.open(URL(string: url)!)
        } label: {
            HStack {
                Text(String(item.position + 1))
                    .font(.cjTitle)
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
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(dependencies.colorThemeManager.appTint.opacity(0.2))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func ticketSection(ticket: Ticket) -> some View {
        VStack {
            Text(ticket.ticketType.label)
                .font(.cjTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack {
                Text(ticket.ticketCategory.label)
                    .font(.cjTitleF)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(ticket.ticketCategory.color)
                    .blur(radius: 1)
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

            if let ticketPrice = concert.ticketPrice {
                HStack {
                    Text("Ticketpreis:")
                        .font(.cjHeadline)

                        Text(ticketPrice.formatted)
                            .font(.cjTitle)
                            .conditionalRedacted(localHidePrices)
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
                .contextMenu {
                    Toggle("Preise ausblenden", isOn: $localHidePrices)
                }
            }

            if let notes = ticket.notes {
                Text(notes)
                    .font(.cjBody)
                    .padding(.horizontal)
            }
        }
        .padding()
        .rectangleGlass()
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

import MapKit
import SwiftUI

struct VenueInlineMap: View {
    let latitude: Double
    let longitude: Double
    let name: String
    
    @State private var position: MapCameraPosition
    
    init(latitude: Double, longitude: Double, name: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        
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
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false) // ⛔️ keine Interaktion
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
