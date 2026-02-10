//
//  ConcertImportView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import MapKit

struct ConcertImportView: View {

    let extractedInfo: ExtractedConcertInfo

    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss

    @State private var isImporting = false
    @State private var errorMessage: String?

    var onImport: (ImportedConcert) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preview Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Importiertes Konzert")
                            .font(.cjCaption)
                            .foregroundColor(.secondary)

                        // Artist
                        HStack {
                            Image(systemName: "music.mic")
                                .foregroundColor(.accentColor)
                            Text(extractedInfo.artistName)
                                .font(.cjTitle2)
                        }

                        // Venue
                        if let venue = extractedInfo.venueName {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.accentColor)
                                Text(venue)
                                    .font(.cjBody)
                            }
                        }

                        // City
                        if let city = extractedInfo.city {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.accentColor)
                                Text(city)
                                    .font(.cjBody)
                            }
                        }

                        // Date
                        if let date = extractedInfo.date {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                Text(date, style: .date)
                                    .font(.cjBody)
                            }
                        }

                        // Price
                        if let price = extractedInfo.price {
                            HStack {
                                Image(systemName: "eurosign")
                                    .foregroundColor(.accentColor)
                                Text(price)
                                    .font(.cjBody)
                            }
                        }

                        // Platform
                        if let platform = extractedInfo.platform {
                            HStack {
                                Image(systemName: "ticket")
                                    .foregroundColor(.accentColor)
                                Text(platform)
                                    .font(.cjFootnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .glassEffect()

                    // Image (if available)
                    if let imageURL = extractedInfo.imageURL,
                       let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                    }

                    // Original Link
                    Link(destination: URL(string: extractedInfo.originalURL)!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Original-Link öffnen")
                                .font(.cjFootnote)
                        }
                        .foregroundColor(.accentColor)
                    }

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.cjBody)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Konzert importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await importConcert()
                        }
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Importieren")
                                .bold()
                        }
                    }
                    .disabled(isImporting)
                }
            }
        }
    }

    func importConcert() async {
        isImporting = true
        errorMessage = nil

        do {
            // Suche oder erstelle Künstler
            let artist = try await searchForExtractedArtist()

            // Suche oder erstelle Venue
            let venue = try await findOrCreateVenue()

            // Erstelle Concert
            let concert = ImportedConcert(
                date: extractedInfo.date ?? Date(),
                venue: venue,
                venueName: extractedInfo.venueName,
                artist: artist,
                artistName: extractedInfo.artistName,
                city: extractedInfo.city,
                rating: nil,
                notes: "Importiert von \(extractedInfo.platform ?? "Link")",
                title: nil
            )

            // Erfolg!
            onImport(concert)

        } catch {
            errorMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }

        isImporting = false
    }

    func searchForExtractedArtist() async throws -> Artist? {
        // Erstelle neuen Künstler
        var importedArtsit: Artist?
        
        importedArtsit = try await dependencies.artistRepository.searchArtists(query: extractedInfo.artistName).first
        
        if importedArtsit == nil {
            let spotifyArtist = try await dependencies.spotifyRepository.searchArtists(query: extractedInfo.artistName, limit: 1, offset: 0)
            if let foundSpotifyArtist = spotifyArtist.first {
                importedArtsit = try await dependencies.artistRepository.getOrCreateArtist(CreateArtistDTO(artist: Artist(artist: foundSpotifyArtist)))
            }
        }

        return importedArtsit
    }

    func findOrCreateVenue() async throws -> Venue? {
        guard let venueName = extractedInfo.venueName, !venueName.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = venueName
        request.resultTypes = .pointOfInterest

        let result = try await MKLocalSearch(request: request).start()
        let bestMatch = result.mapItems.first

        if let bestMatch, let name = bestMatch.name {
            let venue = CreateVenueDTO(name: name,
                                       city: bestMatch.addressRepresentations?.cityName,
                                       formattedAddress: bestMatch.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? "",
                                       latitude: bestMatch.location.coordinate.latitude,
                                       longitude: bestMatch.location.coordinate.longitude,
                                       appleMapsId: bestMatch.identifier?.rawValue)

            let createdVenueId = try await dependencies.venueRepository.createVenue(venue)

            return Venue(id: createdVenueId,
                         name: name,
                         city: venue.city,
                         formattedAddress: venue.formattedAddress,
                         latitude: venue.latitude,
                         longitude: venue.longitude,
                         appleMapsId: venue.appleMapsId)
        } else {
            return nil
        }
    }
}

struct ImportedConcert: Hashable {
    
    let date: Date?
    let venue: Venue?
    let venueName: String?
    let artist: Artist?
    let artistName: String?
    let city: String?
    let rating: String?
    let notes: String?
    let title: String?
}

public struct ExtractedConcertInfo: Codable, Identifiable {
    public var id: String {
        (date?.supabseDateString ?? "NODATE") + artistName + (venueName ?? "NOVENUE") + (city ?? "NOCITY")
    }

    let artistName: String
    let venueName: String?
    let city: String?
    let date: Date?
    let price: String?
    let platform: String?
    let originalURL: String
    let eventID: String?
    let imageURL: String?
}
