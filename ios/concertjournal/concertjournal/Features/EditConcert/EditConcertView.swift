//
//  EditConcertView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 05.01.26.
//

import SwiftUI
import Supabase
import CoreData
import PhotosUI

struct ConcertEditView: View {
    @AppStorage("hidePrices") var hidePrices = false
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencies) var dependencies
    
    @State var title: String
    @State var date: Date
    @State var openingTime: Date
    @State var notes: String
    @State var rating: Int
    @State var venueName: String
    @State var supportActs: [ArtistDTO]
    @State var travel: TravelDTO?
    @State var ticket: TicketDTO?
    
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var newImages: [UIImage] = []
    @State var existingPhotos: [Photo]
    @State var photosToDelete: [Photo] = []
    
    @State var buddyAttendees: [BuddyAttendee]
    @State var buddyPickerPresenting = false
    
    @State var venue: VenueDTO?
    @State var setlistItems: [TempCeateSetlistItem]
    
    @State var selectVenuePresenting = false
    @State var editSeltistPresenting: CreateSetlistViewModel? = nil
    @State var editTravelPresenting = false
    @State var presentTicketEdit = false
    @State var addSupportActPresenting = false
    
    let concert: Concert
    
    let onSave: (ConcertUpdate) -> Void
    
    init(concert: Concert, onSave: @escaping (ConcertUpdate) -> Void) {
        _title = State(initialValue: concert.title ?? "")
        _date = State(initialValue: concert.date)
        _openingTime = State(initialValue: concert.openingTime ?? .now)
        _notes = State(initialValue: concert.notes ?? "")
        _rating = State(initialValue: Int(concert.rating == -1 ? 0 : concert.rating))
        _buddyAttendees = State(initialValue: concert.buddiesArray)
        _venueName = State(initialValue: concert.venue?.name ?? "")
        _venue = State(initialValue: concert.venue?.toDTO())
        _travel = State(initialValue: concert.travel?.toDTO())
        _ticket = State(initialValue: concert.ticket?.toDTO())
        _existingPhotos = State(initialValue: concert.imagesArray)
        
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    
                    editSection(title: "Title:") {
                        TextField(TextKey.fieldTitle.localized, text: $title)
                            .padding()
                            .glassEffect()
                    }
                    
                    editSection(title: "Zeiten") {
                        VStack {
                            DatePicker(TextKey.date.localized, selection: $date, displayedComponents: .date)
                            DatePicker(TextKey.admission.localized, selection: $openingTime, displayedComponents: .hourAndMinute)
                        }
                        .padding(8)
                        .rectangleGlass()
                    }
                    
                    editSection(title: TextKey.supportActs.localized) {
                        supportActsSection()
                    }

                    editSection(title: "Buddies") {
                        buddiesSection()
                    }

                    editSection(title: TextKey.sectionLocation.localized) {
                        VStack(alignment: .leading) {
                            if !venueName.isEmpty {
                                Text(venueName)
                                    .font(.cjBody)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let city = venue?.city {
                                    Text(city)
                                        .font(.cjBody)
                                }
                            }

                            Button {
                                HapticManager.shared.buttonTap()
                                selectVenuePresenting = true
                            } label: {
                                Text(TextKey.venueOptional.localized)
                                    .font(.cjBody)
                            }
                            .padding()
                            .glassEffect()
                        }
                    }

                    editSection(title: TextKey.notes.localized) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .font(.cjBody)
                    }

                    editSection(title: TextKey.travelInfo.localized) {
                        travelSection()
                    }

                    editSection(title: TextKey.ticketInfo.localized) {
                        ticketSection()
                    }

                    editSection(title: TextKey.setlist.localized) {
                        setlistSection
                    }

                    editSection(title: TextKey.review.localized) {
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
                    }

                    editSection(title: "Fotos:") {
                        photosSection()
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle(TextKey.editConcert.localized)
            .tint(dependencies.colorThemeManager.appTint)
            .background {
                Color.background
                    .ignoresSafeArea()
            }
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
                        saveConcertUpdates()
                    } label: {
                        Text(TextKey.save.localized)
                            .font(.cjBody)
                    }
                }
            }
            .sheet(isPresented: $buddyPickerPresenting) {
                BuddyAttendeePickerSheet(selectedAttendees: buddyAttendees, isPresented: $buddyPickerPresenting) { buddies in
                    buddyAttendees = buddies
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
                    print("saved \(items.count) items")
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
            .sheet(isPresented: $editTravelPresenting) {
                CreateConcertTravelView(travel: travel) { travel in
                    self.travel = travel
                    editTravelPresenting = false
                }
            }
            .sheet(isPresented: $presentTicketEdit) {
                CreateConcertTicket(artist: concert.artist.toDTO(), ticketInfo: ticket) { editedTicket in
                    self.ticket = editedTicket
                    presentTicketEdit = false
                }
            }
        }
    }
    
    @ViewBuilder
    func supportActsSection() -> some View {
        VStack(alignment: .leading) {
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
                .padding()
                .rectangleGlass()
            }

            Button {
                addSupportActPresenting = true
            } label: {
                Text(TextKey.addSupportAct.localized)
                    .font(.cjBody)
            }
            .padding()
            .glassEffect()
        }
    }

    func saveConcertUpdates() {
        for image in newImages {
            _ = try? dependencies.offlinePhotoRepsitory.savePhoto(image, for: concert.objectID)
        }

        for photo in photosToDelete {
            try? dependencies.offlinePhotoRepsitory.deletePhoto(photo)
        }

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
                buddyAttendees: buddyAttendees,
                travel: travel,
                ticket: ticket,
                supportActs: supportActs,
                setlistItems: setlistItems,
                photos: []
            )
        )
        dismiss()
    }

    func correctedOpeningTime() -> Date {
        let openingTime = self.openingTime
        let date = self.date
        
        let calendar = Calendar.current
        let openingHourAndMinute = calendar.dateComponents([.hour, .minute], from: openingTime)
        guard let hour = openingHourAndMinute.hour,
              let minute = openingHourAndMinute.minute else { return openingTime }
        
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? openingTime
    }
    
    func editSection(title: String, content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.cjCaption)
            content()
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var presenting: Bool = true
    
    let context = PreviewPersistenceController.shared.container.viewContext
    let concert = Concert.preview(in: context)
    
    VStack {
        Button("present") {
            presenting = true
        }
    }
    .sheet(isPresented: $presenting) {
        ConcertEditView(concert: concert, onSave: { _ in })
    }
}
#endif
