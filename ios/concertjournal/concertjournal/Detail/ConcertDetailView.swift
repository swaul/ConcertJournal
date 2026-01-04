//
//  ConcertDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 01.01.26.
//

import Combine
import SwiftUI
import Supabase

class ConcertDetailViewModel: ObservableObject {
    
    let concert: FullConcertVisit
    let artist: Artist
    
    @Published var imageUrls: [URL] = []
    
    init(concert: FullConcertVisit) {
        self.concert = concert
        self.artist = concert.artist
        Task {
            do {
                try await loadImages()
            } catch {
                print("Failed to load images. Error: \(error)")
            }
        }
    }
    
    func loadImages() async throws {
        let photos: [ConcertPhotoInsertDTO] = try await SupabaseManager.shared.client
            .from("concert_photos")
            .select()
            .eq("concert_visit_id", value: concert.id)
            .order("created_at")
            .execute()
            .value
        
        imageUrls = photos.compactMap { URL(string: $0.publicUrl) }
    }
}

struct ConcertDetailView: View {
    
    @StateObject var viewModel: ConcertDetailViewModel
    
    init(concert: FullConcertVisit) {
        self._viewModel = StateObject(wrappedValue: ConcertDetailViewModel(concert: concert))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ArtistHeader(artist: viewModel.artist)
                
                HStack {
                    Spacer()
                    Text(viewModel.concert.date.dateOnlyString)
                        .bold()
                        .font(.system(size: 30))
                        .padding()
                        .glassEffect()
                        .padding(.horizontal)
                    Spacer()
                }
                if let venue = viewModel.concert.venue {
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
                
                ForEach(viewModel.imageUrls, id: \.self) {
                    AsyncImage(url: $0) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .cornerRadius(20)
                    } placeholder: {
                        ProgressView()
                    }
                }
                .padding()
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
