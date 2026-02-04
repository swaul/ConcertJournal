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

struct ConcertImage: Identifiable {
    let url: URL
    let id: String
    let index: Int
}

struct ConcertDetailView: View {

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
            guard viewModel == nil else { return }
            viewModel = ConcertDetailViewModel(concert: concert,
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

                        if let setlistItems = viewModel.setlistItems, !setlistItems.isEmpty {
                            Text("Setlist")
                                .font(.cjTitle)
                                .padding(.horizontal)
                            
                            VStack {
                                ForEach(setlistItems, id: \.spotifyTrackId) { item in
                                    makeSetlistItemView(with: item)
                                }
                            }
                            .padding()
                            .rectangleGlass()
                            .padding(.horizontal)
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
                        await viewModel.applyUpdate(updatedConcert)
                        confirmationText = ConfirmationMessage(message: "Updates gespeichert!")
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

