//
//  MapView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 05.01.26.
//

import MapKit
import SwiftUI

struct MapView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.navigationManager) var navigationManager

    @State private var viewModel: MapViewModel?

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedItem: ConcertMapItem?
    @State private var pendingItem: ConcertMapItem?
    @State private var isCameraMoving = false

    @State private var defaultPosition: MapCameraPosition? = nil

    @State private var selectedDetent: PresentationDetent = .height(330)
    @State private var detentHeight: CGFloat = 330

    @State private var triggerWobble: Bool = false
    
    var body: some View {
        NavigationStack {
            @Bindable var navigationManager = navigationManager

            Group {
                if let viewModel {
                    map(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .task {
                guard viewModel == nil else {
                    return
                }

                viewModel = MapViewModel()
            }
        }
    }

    @ViewBuilder
    func map(viewModel: MapViewModel) -> some View {
        Map(position: $position) {
            ForEach(viewModel.concertLocations) { item in
                Annotation(item.venueName, coordinate: item.coordinates) {
                    ConcertMapPin(concert: item, triggerWobble: $triggerWobble)
                        .onTapGesture {
                            let targetRegion = region(for: item)
                            pendingItem = item
                            
                            if let currentRegion = position.region,
                               currentRegion.isApproximatelyEqual(to: targetRegion) {
                                
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedItem = item
                                    pendingItem = nil
                                }
                            } else {
                                withAnimation(.easeInOut) {
                                    position = .region(targetRegion)
                                }
                            }
                        }
                }
            }
        }
        .toolbar {
            if let defaultPosition {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.buttonTap()
                        withAnimation {
                            position = defaultPosition
                        }
                    } label: {
                        Text("Alle anzeigen")
                            .font(.cjBody)
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) {
            triggerWobble.toggle()
            if let pendingItem {
                withAnimation(.easeInOut(duration: 0.35).delay(0.2)) {
                    selectedItem = pendingItem
                    self.pendingItem = nil
                }
            }
        }
        .mapStyle(.standard)
        .sheet(item: $selectedItem) { item in
            detailInfo(item: item)
                .presentationDetents([.height(330), .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .onChange(of: selectedDetent) { _, newValue in
            let height: CGFloat
            switch selectedDetent {
            case .height(330):
                height = 330
            default:
                height = 0
            }

            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                detentHeight = height
            }
        }
        .safeAreaInset(edge: .bottom) {
            Rectangle()
                .fill(.clear)
                .frame(width: 100, height: selectedItem == nil ? 0 : detentHeight)
        }
        .onAppear {
            position = .automatic
            defaultPosition = position
        }
    }

    func detailInfo(item: ConcertMapItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(item.venueName)
                    .bold()
                    .font(.cjTitle)
                    .padding()
                    .rectangleGlass()
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedItem = nil
                    }
                } label: {
                    Text("Close")
                        .font(.cjBody)
                }
                .buttonStyle(.glass)
            }
            .padding()
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(item.concerts, id: \.self) { concert in
                        Button {
                            HapticManager.shared.navigationTap()
                            navigationManager.selectedTab = .concerts
                            navigationManager.push(.concertDetail(concert))
                            selectedItem = nil
                        } label: {
                            HStack {
                                VStack {
                                    Text(concert.date.shortDateOnlyString)
                                        .font(.cjCaption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60)

                                    Group {
                                        AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .clipShape(Circle())
                                        } placeholder: {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 60, height: 60)
                                }
                                VStack(alignment: .leading) {
                                    Text(concert.artist.name)
                                        .font(.cjTitle2)
                                        .bold()
                                        .multilineTextAlignment(.leading)

                                    if let title = concert.title {
                                        Text(title)
                                            .font(.cjBody)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .frame(alignment: .trailing)
                            }
                            .padding()
                            .rectangleGlass()
                            .frame(maxWidth: .infinity)
                        }

                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    func region(for item: ConcertMapItem) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: item.coordinates,
            span: MKCoordinateSpan(
                latitudeDelta: 0.003,
                longitudeDelta: 0.003
            )
        )
    }
}

struct ConcertMapItem: Identifiable, Equatable {
    static func == (lhs: ConcertMapItem, rhs: ConcertMapItem) -> Bool {
        lhs.venueName == rhs.venueName
    }

    var id: String {
        venueName
    }

    let venueName: String
    let coordinates: CLLocationCoordinate2D
    let concerts: [Concert]
    let artists: [Artist]

    var title: String {
        concerts.count == 1 ? concerts.first!.title ?? concerts.first!.artist.name : "\(concerts.count) Konzerte"
    }
}

struct ConcertMapPin: View {
    @Environment(\.dependencies) var dependencies

    let concert: ConcertMapItem
    @State private var showArtists = false
    @Binding var triggerWobble: Bool
    
    // Positionen im Kreis um den Pin herum
    func offset(for index: Int, total: Int) -> CGSize {
        let angle = (2 * .pi / Double(total)) * Double(index) - .pi / 2
        let radius: Double = 50
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
    
    var body: some View {
        ZStack {
            // Kleine Artist-Bilder rundherum
            ForEach(Array(concert.artists.enumerated()), id: \.offset) { index, artist in
                ArtistBubble(artist: artist)
                    .offset(showArtists ? offset(for: index, total: concert.artists.count) : .zero)
                    .scaleEffect(showArtists ? 1 : 0.3)
                    .opacity(showArtists ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(Double(index) * 0.08), // Staffelung wie beim Mac
                        value: showArtists
                    )
                    .keyframeAnimator(initialValue: 1.0, trigger: triggerWobble) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.15, duration: 0.15)
                        SpringKeyframe(0.95, duration: 0.15)
                        SpringKeyframe(1.0, duration: 0.2)
                    }
            }
            
            Text("\(concert.concerts.count)")
                .font(.cjTitle)
                .foregroundStyle(dependencies.colorThemeManager.appTint)
                .bold()
                .frame(minWidth: 10)
                .padding()
                .glassEffect(in: Circle())
        }
        .onAppear {
            withAnimation {
                showArtists = true
            }
        }
    }
}

struct ArtistBubble: View {
    @Environment(\.dependencies) var dependencies

    let artist: Artist
    
    var imageUrl: URL? {
        URL(string: artist.imageUrl ?? "")
    }
    
    var body: some View {
        AsyncImage(url: imageUrl) { image in
            image.resizable()
        } placeholder: {
            Circle().fill(.gray.opacity(0.3))
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(dependencies.colorThemeManager.appTint.opacity(0.2), lineWidth: 2))
        .shadow(radius: 3)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension MKCoordinateRegion {
    func isApproximatelyEqual(
        to other: MKCoordinateRegion,
        tolerance: CLLocationDegrees = 0.0005
    ) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance &&
        abs(center.longitude - other.center.longitude) < tolerance &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
}
