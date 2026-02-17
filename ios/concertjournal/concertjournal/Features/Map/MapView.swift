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

    var body: some View {
        NavigationStack {
            @Bindable var navigationManager = navigationManager

            Group {
                if let viewModel, !viewModel.isLoading {
                    map(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = MapViewModel(concertRepository: dependencies.concertRepository)
            }
        }
    }

    @ViewBuilder
    func map(viewModel: MapViewModel) -> some View {
        Map(position: $position) {
            ForEach(viewModel.concertLocations) { item in
                Annotation(item.venueName, coordinate: item.coordinates) {
                    Text("\(item.concerts.count)")
                        .font(.cjBody)
                        .bold()
                        .frame(minWidth: 10)
                        .padding()
                        .glassEffect(in: Circle())
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
        .onChange(of: viewModel.concertLocations) { _, newValue in
            position = .region(MKCoordinateRegion(center: Self.centerCoordinate(of: newValue),
                                                  span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
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
                .interactiveDismissDisabled()
        }
        .onChange(of: selectedDetent) { _, newValue in
            let height: CGFloat
            switch selectedDetent {
            case .height(330):
                height = 330
            default:
                height = 0
            }

            withAnimation {
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
                    .glassEffect()
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
                                    Text(concert.date.supabseDateString)
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

    static func centerCoordinate(of items: [ConcertMapItem]) -> CLLocationCoordinate2D {
        let latitudes = items.map { $0.coordinates.latitude }
        let longitudes = items.map { $0.coordinates.longitude }

        return CLLocationCoordinate2D(
            latitude: latitudes.reduce(0, +) / Double(latitudes.count),
            longitude: longitudes.reduce(0, +) / Double(longitudes.count)
        )
    }
}

struct ConcertMapItem: Identifiable, Equatable {
    static func == (lhs: ConcertMapItem, rhs: ConcertMapItem) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let venueName: String
    let coordinates: CLLocationCoordinate2D
    let concerts: [Concert]

    var title: String {
        concerts.count == 1 ? concerts.first!.title ?? concerts.first!.artist.name : "\(concerts.count) Konzerte"
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
