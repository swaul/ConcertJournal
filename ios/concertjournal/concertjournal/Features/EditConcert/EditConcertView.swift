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
    @State private var openingTime: Date
    @State private var notes: String
    @State private var rating: Int
    @State private var venueName: String
    @State private var supportActs: [ArtistDTO]
    @State private var travel: TravelDTO?
    @State private var ticket: TicketDTO?

    @State private var venue: VenueDTO?
    @State private var setlistItems: [TempCeateSetlistItem]

    @State private var selectVenuePresenting = false
    @State private var editSeltistPresenting: CreateSetlistViewModel? = nil
    @State private var editTravelPresenting = false
    @State private var presentTicketEdit = false
    @State private var addSupportActPresenting = false

    let concert: Concert

    let onSave: (ConcertUpdate) -> Void

    init(concert: Concert, onSave: @escaping (ConcertUpdate) -> Void) {
        _title = State(initialValue: concert.title ?? "")
        _date = State(initialValue: concert.date)
        _openingTime = State(initialValue: concert.openingTime ?? .now)
        _notes = State(initialValue: concert.notes ?? "")
        _rating = State(initialValue: Int(concert.rating == -1 ? 0 : concert.rating))
        _venueName = State(initialValue: concert.venue?.name ?? "")
        _venue = State(initialValue: concert.venue?.toDTO())
        _travel = State(initialValue: concert.travel?.toDTO())
        _ticket = State(initialValue: concert.ticket?.toDTO())
        if !concert.setlistItemsArray.isEmpty {
            let tempSetlistItems = concert.setlistItemsArray.map { TempCeateSetlistItem(setlistItem: $0) }
            _setlistItems = State(initialValue: tempSetlistItems)
        } else {
            _setlistItems = State(initialValue: [])
        }
        if !concert.supportActsArray.isEmpty {
            _supportActs = State(initialValue: concert.supportActsArray.map { $0.toDTO() })
        } else {
            _supportActs = State(initialValue: [])
        }

        self.concert = concert
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(TextKey.fieldTitle.localized, text: $title)
                    DatePicker(TextKey.fieldDate.localized, selection: $date, displayedComponents: .date)
                    DatePicker(TextKey.fieldAdmission.localized, selection: $openingTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text(TextKey.concert.localized)
                        .font(.cjBody)
                }

                Section {
                    supportActsSection()
                } header: {
                    Text(TextKey.sectionSupportActs.localized)
                        .font(.cjBody)
                }

                Section {
                    Button {
                        HapticManager.shared.buttonTap()
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
                            Text(TextKey.fieldVenueOptional.localized)
                                .font(.cjBody)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(TextKey.sectionLocation.localized)
                        .font(.cjBody)
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .font(.cjBody)
                } header: {
                    Text(TextKey.fieldNotes.localized)
                        .font(.cjBody)
                }
                
                Section {
                    travelSection()
                } header: {
                    Text(TextKey.travelInfo.localized)
                        .font(.cjBody)
                }

                Section {
                    ticketSection()
                } header: {
                    Text(TextKey.ticketInfo.localized)
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
                            HapticManager.shared.buttonTap()
                            editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)

                        } label: {
                            Text(TextKey.editSetlist.localized)
                                .font(.cjBody)
                        }
                    } else {
                        Button {
                            HapticManager.shared.buttonTap()
                            editSeltistPresenting = CreateSetlistViewModel(currentSelection: setlistItems, spotifyRepository: dependencies.spotifyRepository, setlistRepository: dependencies.setlistRepository)
                        } label: {
                            Text(TextKey.addSetlist.localized)
                                .font(.cjBody)
                        }
                    }
                } header: {
                    Text(TextKey.setlist.localized)
                        .font(.cjBody)
                }

                Section {
                    Stepper(value: $rating, in: 0...10) {
                        HStack {
                            Text(TextKey.fieldRating.localized)
                                .font(.cjBody)
                            Spacer()
                            Text("\(rating)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .font(.cjBody)
                        }
                    }
                } header: {
                    Text(TextKey.fieldReview.localized)
                        .font(.cjBody)
                }
            }
            .navigationTitle(TextKey.navEditConcert.localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Text(TextKey.cancel.localized)
                            .font(.cjBody)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.shared.buttonTap()
                        onSave(
                            ConcertUpdate(
                                id: concert.id,
                                title: title,
                                date: date,
                                openingTime: correctedOpeningTime(),
                                notes: notes,
                                venue: venue,
                                city: venue?.city,
                                rating: rating,
                                travel: travel,
                                ticket: ticket,
                                supportActs: supportActs,
                                setlistItems: setlistItems,
                                photos: []
                            )
                        )
                        dismiss()
                    } label: {
                        Text(TextKey.save.localized)
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
            .sheet(isPresented: $addSupportActPresenting) {
                CreateConcertSelectArtistView(isPresented: $addSupportActPresenting, didSelectArtist: { artist in
                    withAnimation {
                        self.addSupportActPresenting = false
                    } completion: {
                        withAnimation {
                            supportActs.append(artist)
                        }
                    }
                })
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
                Text(TextKey.travelDurationWas.localized(with: parsedDuration))
            }
            if let travelDistance = travel?.travelDistance {
                let parsedDistance = DistanceParser.format(travelDistance)
                Text(TextKey.travelDistanceWas.localized(with: parsedDistance))
            }
            if let arrivedAt = travel?.arrivedAt {
                Text(TextKey.travelArrived.localized(with: arrivedAt.timeOnlyString))
            }
            if let travelExpenses = travel?.travelExpenses {
                Text(TextKey.travelCostWas.localized(with: travelExpenses.formatted))
            }
            if let hotelExpenses = travel?.hotelExpenses {
                Text(TextKey.travelHotelCost.localized(with: hotelExpenses.formatted))
            }
            
            Button {
                editTravelPresenting = true
            } label: {
                Text(TextKey.addTravelInfo.localized)
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
    func supportActsSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !supportActs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(supportActs) { artist in
                            ArtistChipView(artist: artist, removeable: true) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    supportActs.removeAll(where: { $0.id == artist.id })
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
                Text(TextKey.addSupportAct.localized)
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
            .padding(.horizontal)
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
                                Text(TextKey.fieldBlock.localized)
                                    .font(.cjHeadline)
                            }
                            if ticket.seatRow != nil {
                                Text(TextKey.fieldRow.localized)
                                    .font(.cjHeadline)
                            }
                            if ticket.seatNumber != nil {
                                Text(TextKey.fieldSeat.localized)
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

                if let ticketPrice = concert.ticket?.ticketPrice {
                    HStack {
                        Text(TextKey.ticketPriceColon.localized)
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
                    Text(TextKey.addTicket.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
                .padding(.horizontal)
            } else {
                Button {
                    presentTicketEdit = true
                } label: {
                    Text(TextKey.addTicket.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $presentTicketEdit) {
            CreateConcertTicket(artist: concert.artist.toDTO(), ticketInfo: ticket) { editedTicket in
                self.ticket = editedTicket
                presentTicketEdit = false
            }
        }
    }

    func importPlaylistToSetlist() async throws {
        logInfo("Provider token found, loading playlists", category: .viewModel)

        let playlists = try await dependencies.spotifyRepository.getUserPlaylists(limit: 50)
        print(playlists)
    }

    func correctedOpeningTime() -> Date {
        var openingTime = self.openingTime
        var date = self.date

        let calendar = Calendar.current
        let openingHourAndMinute = calendar.dateComponents([.hour, .minute], from: openingTime)
        guard let hour = openingHourAndMinute.hour,
              let minute = openingHourAndMinute.minute else { return openingTime }

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? openingTime
    }
}

struct ConcertUpdate {
    let id: UUID
    let title: String?
    let date: Date
    let openingTime: Date?
    let notes: String?
    let venue: VenueDTO?
    let city: String?
    let rating: Int?
    
    let travel: TravelDTO?
    let ticket: TicketDTO?
    let supportActs: [ArtistDTO]?
    let setlistItems: [TempCeateSetlistItem]?
    let photos: [ConcertPhoto]
}
