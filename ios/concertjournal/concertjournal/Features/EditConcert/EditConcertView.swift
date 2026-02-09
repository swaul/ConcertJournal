//
//  EditConcertView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 05.01.26.
//

import SwiftUI
import Supabase

struct ConcertEditView: View {
    @AppStorage("hidePrices") private var hidePrices = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    
    @State private var title: String
    @State private var date: Date
    @State private var notes: String
    @State private var rating: Int
    @State private var venueName: String
    @State private var travel: Travel?
    @State private var ticket: Ticket?

    @State private var venue: Venue?
    @State private var setlistItems: [TempCeateSetlistItem]

    @State private var selectVenuePresenting = false
    @State private var editSeltistPresenting: CreateSetlistViewModel? = nil
    @State private var editTravelPresenting = false
    @State private var presentTicketEdit = false

    let concert: FullConcertVisit
    
    let onSave: (ConcertUpdate) -> Void

    init(concert: FullConcertVisit, onSave: @escaping (ConcertUpdate) -> Void) {
        _title = State(initialValue: concert.title ?? "")
        _date = State(initialValue: concert.date)
        _notes = State(initialValue: concert.notes ?? "")
        _rating = State(initialValue: concert.rating ?? 0)
        _venueName = State(initialValue: concert.venue?.name ?? "")
        _venue = State(initialValue: concert.venue)
        _travel = State(initialValue: concert.travel)
        _ticket = State(initialValue: concert.ticket)
        if let setlistItems = concert.setlistItems {
            let tempSetlistItems = setlistItems.map { TempCeateSetlistItem(setlistItem: $0) }
            _setlistItems = State(initialValue: tempSetlistItems)
        } else {
            _setlistItems = State(initialValue: [])
        }

        self.concert = concert
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title)
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Konzert")
                        .font(.cjBody)
                }

                Section {
                    Button {
                        selectVenuePresenting = true
                    } label: {
                        if !venueName.isEmpty {
                            VStack(alignment: .leading) {
                                Text(venueName)
                                    .font(.cjBody)
                                if let city = venue?.city {
                                    Text(city)
                                        .font(.cjBody)
                                }
                            }
                        } else {
                            Text("Venue auswählen (optional)")
                                .font(.cjBody)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Location")
                        .font(.cjBody)
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .font(.cjBody)
                } header: {
                    Text("Notizen")
                        .font(.cjBody)
                }
                
                Section {
                    travelSection()
                } header: {
                    Text("Reiseinfos")
                        .font(.cjBody)
                }

                Section {
                    ticketSection()
                } header: {
                    Text("Ticketinfo")
                        .font(.cjBody)
                }

                Section {
                    if !setlistItems.isEmpty {
                        List {
                            ForEach(setlistItems.enumerated(), id: \.element.id) { index, item in
                                makeEditSongView(index: index, song: item)
                            }
                            .onMove { indexSet, offset in
                                setlistItems.move(fromOffsets: indexSet, toOffset: offset)
                                updateSetlistItems()
                            }
                            .onDelete { indexSet in
                                setlistItems.remove(atOffsets: indexSet)
                                updateSetlistItems()
                            }
                        }
                        Button {
                            editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)

                        } label: {
                            Text("Setlist hinzufügen")
                                .font(.cjBody)
                        }
                    } else {
                        Button {
                            editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)
                        } label: {
                            Text("Setlist hinzufügen")
                                .font(.cjBody)
                        }
                    }
                } header: {
                    Text("Setlist")
                        .font(.cjBody)
                }

                Section {
                    Stepper(value: $rating, in: 0...10) {
                        HStack {
                            Text("Rating")
                                .font(.cjBody)
                            Spacer()
                            Text("\(rating)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .font(.cjBody)
                        }
                    }
                } header: {
                    Text("Bewertung")
                        .font(.cjBody)
                }
            }
            .navigationTitle("Konzert bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Abbrechen")
                            .font(.cjBody)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(
                            ConcertUpdate(
                                id: concert.id,
                                title: title,
                                date: date.supabseDateString,
                                notes: notes,
                                venue: venue,
                                city: venue?.city,
                                rating: rating,
                                travel: travel,
                                ticket: ticket,
                                setlistItems: setlistItems,
                                photos: []
                            )
                        )
                        dismiss()
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
            .sheet(isPresented: $selectVenuePresenting) {
                CreateConcertSelectVenueView(isPresented: $selectVenuePresenting, onSelect: { venue in
                    self.venueName = venue.name
                    self.venue = venue
                })
            }
            .sheet(item: $editSeltistPresenting) { item in
                CreateSetlistView(viewModel: item) { items in
                    setlistItems = items
                    editSeltistPresenting = nil
                }
            }
        }
    }

    @ViewBuilder
    func makeEditSongView(index: Int, song: TempCeateSetlistItem) -> some View {
        HStack {
            Grid(verticalSpacing: 8) {
                GridRow {
                    Text("\(index + 1).")
                        .font(.cjTitle2)
                        .frame(width: 28)
                    Text(song.title)
                        .font(.cjHeadline)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                    GridRow {
                        Rectangle().fill(.clear)
                            .frame(width: 28, height: 1)

                        Text(song.artistNames)
                            .font(.cjBody)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
            }
            .frame(maxWidth: .infinity)
            Image(systemName: "line.3.horizontal")
                .frame(width: 28)
        }
    }
    
    func updateSetlistItems() {
        setlistItems.enumerated().forEach { index, _ in
            setlistItems[index].position = index
        }
    }

    @ViewBuilder
    func travelSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let travelType = travel?.travelType {
                Text(travelType.infoText(color: dependencies.colorThemeManager.appTint))
            }
            if let travelDuration = travel?.travelDuration {
                let parsedDuration = DurationParser.format(travelDuration)
                Text("Die Reise hat \(parsedDuration) gedauert.")
            }
            if let travelDistance = travel?.travelDistance {
                let parsedDistance = DistanceParser.format(travelDistance)
                Text("Der Weg war \(parsedDistance) lang.")
            }
            if let travelExpenses = travel?.travelExpenses {
                Text("Die Anreise hat dich \(travelExpenses.formatted) gekostet.")
            }
            if let hotelExpenses = travel?.hotelExpenses {
                Text("Und für die Übernachtung hast du \(hotelExpenses.formatted) gezahlt.")
            }
            
            Button {
                editTravelPresenting = true
            } label: {
                Text("Reiseinfos hinzufügen")
            }
            .padding()
            .glassEffect()
        }
        .padding(.horizontal)
        .font(.cjBody)
        .sheet(isPresented: $editTravelPresenting) {
            CreateConcertTravelView(travel: travel) { travel in
                self.travel = travel
                editTravelPresenting = false
            }
        }
    }

    @ViewBuilder
    func ticketSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ticket = ticket {
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
                    RoundedRectangle(cornerRadius: 20).fill(ticket.ticketCategory.color)
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

                if let ticketPrice = concert.ticketPrice {
                    HStack {
                        Text("Ticketpreis:")
                            .font(.cjHeadline)

                        Text(ticketPrice.formatted)
                            .font(.cjTitle)
                            .conditionalRedacted(hidePrices)
                    }
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Toggle("Preise ausblenden", isOn: $hidePrices)
                    }
                }

                Button {
                    presentTicketEdit = true
                } label: {
                    Text("Ticket hinzufügen")
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
                .padding(.horizontal)
            } else {
                Button {
                    presentTicketEdit = true
                } label: {
                    Text("Ticket hinzufügen")
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $presentTicketEdit) {
            CreateConcertTicket(artist: concert.artist, ticketInfo: ticket) { editedTicket in
                self.ticket = editedTicket
                presentTicketEdit = false
            }
        }
    }

    func importPlaylistToSetlist() async throws {
        try await dependencies.userSessionManager.refreshSpotifyProviderTokenIfNeeded()
        guard let providerToken = dependencies.userSessionManager.providerToken else { throw SpotifyError.noProviderToken }

        logInfo("Provider token found, loading playlists", category: .viewModel)

        let playlists = try await dependencies.spotifyRepository.getUserPlaylists(limit: 50)
        print(playlists)
    }
}

struct ConcertUpdate {
    let id: String
    let title: String
    let date: String
    let notes: String
    let venue: Venue?
    let city: String?
    let rating: Int
    
    let travel: Travel?
    let ticket: Ticket?
    let setlistItems: [TempCeateSetlistItem]?
    let photos: [Photo]
}
