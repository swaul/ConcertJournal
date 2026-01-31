//
//  ConcertDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 01.01.26.
//

import Combine
import SwiftUI
import Supabase
import EventKit
import EventKitUI

struct ConcertImage: Identifiable {
    let url: URL
    let id: String
    let index: Int
}

@Observable
class ConcertDetailViewModel {
    
    var concert: FullConcertVisit
    let artist: Artist
    var imageUrls: [ConcertImage] = []

    private let photoRepository: PhotoRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol

    init(concert: FullConcertVisit, concertRepository: ConcertRepositoryProtocol, photoRepository: PhotoRepositoryProtocol) {
        self.concert = concert
        self.artist = concert.artist

        self.photoRepository = photoRepository
        self.concertRepository = concertRepository

        Task {
            do {
                try await loadImages()
            } catch {
                print("Failed to load images. Error: \(error)")
            }
        }
    }
    
    func loadImages() async throws {
        let photos: [ConcertPhoto] = try await photoRepository.fetchPhotos(for: concert.id)
        
        let urls = photos.compactMap { URL(string: $0.publicUrl) }.enumerated().map { (index, url) in
            ConcertImage(url: url, id: url.absoluteString, index: index)
        }
        
        imageUrls = urls
    }
    
    func createCalendarEntry(store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        
        let endDate = Calendar.current.date(byAdding: .hour, value: 3, to: concert.date)
        
        event.title = concert.title
        event.startDate = concert.date
        event.endDate = endDate
        event.notes = concert.notes
        if let venue = concert.venue, let latitude = venue.latitude, let longitude = venue.longitude {
            event.structuredLocation = EKStructuredLocation(mapItem: MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: MKAddress(fullAddress: venue.formattedAddress, shortAddress: nil)))
        } else {
            event.location = concert.venue?.formattedAddress
        }
        event.calendar = store.defaultCalendarForNewEvents
        
        return event
    }
    
    func applyUpdate(_ update: ConcertUpdate) async {
        // Create an updated model by keeping immutable fields and applying edits
        let updated = FullConcertVisit(
            id: concert.id,
            createdAt: concert.createdAt,
            updatedAt: Date(),
            date: update.date,
            venue: update.venue,
            city: update.city,
            rating: update.rating,
            title: update.title,
            notes: update.notes,
            artist: concert.artist
        )
        
        // Assign back to published state so UI updates
        self.concert = updated
        
        let dto = ConcertVisitUpdateDTO(update: update)
        
        do {
            try await concertRepository.updateConcert(id: concert.id, concert: dto)
        } catch {
            print("Update failed:", error)
            // optional: rollback
        }
    }
}

struct ConcertDetailView: View {
    
    @Environment(\.dependencies) private var dependencies

    @State var viewModel: ConcertDetailViewModel?

    let concert: FullConcertVisit
    
    @State private var showCalendarSheet = false
    @State private var calendarEvent: EKEvent?
    @State private var confirmationText: ConfirmationMessage? = nil
    @State private var showEditSheet = false
    
    @State private var selectedImage: ConcertImage?
    
    let eventStore = EKEventStore()
    
    var body: some View {
        Group {
            if let viewModel {
                GeometryReader { reader in
                    ZStack {
                        VStack {
                            ConcertBackgroundImage(width: reader.size.width, imageUrl: viewModel.artist.imageUrl ?? "")
                                .edgesIgnoringSafeArea(.top)

                            Spacer()
                        }
                        .frame(width: reader.size.width)
                        .edgesIgnoringSafeArea(.top)

                        ScrollView {
                            VStack(alignment: .leading) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.concert.date.dateOnlyString)
                                        .font(.system(size: 22))
                                    if let title = viewModel.concert.title {
                                        Text(title)
                                            .bold()
                                            .font(.system(size: 30))
                                    } else {
                                        Text(viewModel.artist.name)
                                            .bold()
                                            .font(.system(size: 30))
                                    }
                                }
                                .padding()
                                .rectangleGlass()
                                .padding(.horizontal)

                                if let venue = viewModel.concert.venue {
                                    Text("Location")
                                        .font(.system(size: 28))
                                        .padding(.horizontal)

                                    VStack(alignment: .leading) {
                                        Text(venue.name)
                                            .bold()
                                            .font(.system(size: 26))

                                        Text(venue.formattedAddress)

                                        if let latitude = venue.latitude, let longitude = venue.longitude {
                                            VenueInlineMap(latitude: latitude, longitude: longitude, name: venue.name)
                                        }
                                    }
                                    .padding()
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                                    .padding(.horizontal)
                                }

                                if let notes = viewModel.concert.notes {
                                    Text("Meine Experience")
                                        .font(.system(size: 28))
                                        .padding(.horizontal)

                                    VStack(alignment: .leading) {
                                        HStack(alignment: .center) {
                                            Image(systemName: "long.text.page.and.pencil")
                                                .foregroundStyle(dependencies.colorThemeManager.appTint.opacity(0.5))
                                            Text("Journal Eintrag")
                                                .foregroundStyle(dependencies.colorThemeManager.appTint.opacity(0.5))
                                            Spacer()
                                        }
                                        .padding(.top)
                                        .padding(.horizontal)

                                        Text(notes)
                                            .lineLimit(nil)
                                            .padding(.bottom)
                                            .padding(.horizontal)
                                    }
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                                    .padding(.horizontal)
                                }

                                if !viewModel.imageUrls.isEmpty {
                                    Text("Meine Bilder")
                                        .font(.system(size: 28))
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

                        Button {
                            showEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                        }
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
                                await viewModel.applyUpdate(updatedConcert)
                                confirmationText = ConfirmationMessage(message: "Updates gespeichert!")
                            }
                        }
                    )
                }
                .sheet(item: $confirmationText) { item in
                    ConfirmationView(message: item.message)
                }
                .fullScreenCover(item: $selectedImage) { item in
                    FullscreenImagePagerView(
                        imageUrls: viewModel.imageUrls,
                        startIndex: item.index
                    )
                }
            } else {
                LoadingView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = ConcertDetailViewModel(concert: concert,
                                               concertRepository: dependencies.concertRepository,
                                               photoRepository: dependencies.photoRepository)
        }

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
                .year()
                .month()
                .day()
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

