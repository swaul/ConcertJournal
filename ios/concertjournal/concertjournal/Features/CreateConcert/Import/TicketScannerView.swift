//
//  TicketScannerView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 11.02.26.
//

import SwiftUI
import PhotosUI
import Vision
import VisionKit
import MapKit

// MARK: - Ticket Scanner View

struct TicketScannerView: View {
    
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager
    
    @State var cameraManager = CameraManager()
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var extractedInfo: TicketInfo?
    @State private var errorMessage: String?
    
    //    var onConcertExtracted: (TicketInfo) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if cameraManager.permissionGranted {
                if let image = selectedImage {
                    // Image Preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    
                    if isScanning {
                        // Scanning State
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Scanne Ticket...")
                                .font(.cjBody)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let info = extractedInfo {
                        // Extracted Info Preview
                        ExtractedTicketInfoCard(info: info)
                        
                        Button {
                            expotToConcertCreation(info: info)
                        } label: {
                            Text("Konzert erstellen")
                                .font(.cjHeadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                    } else if let error = errorMessage {
                        // Error State
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.cjBody)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Nochmal versuchen") {
                                selectedImage = nil
                                errorMessage = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                    
                } else {
                    emptyState
                }
            }
            Spacer()
        }
        .padding(.vertical)
        .navigationTitle("Ticket scannen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cameraManager.requestPermission()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    navigationManager.popToRoot()
                }
            }
            
            if selectedImage != nil && extractedInfo == nil && !isScanning {
                ToolbarItem(placement: .primaryAction) {
                    Button("Manuell eingeben") {
                        // Fallback: Manual entry
                        navigationManager.push(.createConcert)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await scanTicket(image: image)
                }
            }
        }
    }
    
    // MARK: - Ticket Scanning
    
    private func scanTicket(image: UIImage) async {
        isScanning = true
        errorMessage = nil
        extractedInfo = nil
        
        do {
            // Try Apple Intelligence first (iOS 18.2+)
            if #available(iOS 18.2, *) {
                if let info = try await scanWithAppleIntelligence(image: image) {
                    extractedInfo = info
                    isScanning = false
                    return
                }
            }
            
            // Fallback: Vision Framework OCR
            let info = try await scanWithVisionOCR(image: image)
            extractedInfo = info
            
        } catch {
            errorMessage = "Konnte Ticket nicht lesen. Bitte versuche es erneut oder gib die Daten manuell ein."
            logError("Ticket scan failed", error: error, category: .import)
        }
        
        isScanning = false
    }
    
    // Empty State
    @ViewBuilder
    var emptyState: some View {
        VStack(spacing: 30) {
            Image(systemName: "ticket")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Scanne dein Ticket")
                .font(.cjTitle2)
            
            Text("Fotografiere dein Konzert-Ticket oder wähle ein Foto aus deiner Galerie")
                .font(.cjBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Kamera öffnen", systemImage: "camera")
                        .font(.cjHeadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    showImagePicker = true
                } label: {
                    Label("Aus Galerie wählen", systemImage: "photo.on.rectangle")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func expotToConcertCreation(info: TicketInfo) {
        Task {
            do {
                var info = info
                
                info.artist = try await searchForExtractedArtist(artistName: info.artistName)
                info.venue = try await findOrCreateVenue(venueName: info.venueName)
                
                navigationManager.push(.createConcertFromTicket(info))
            } catch {
                logError("Error with import", error: error, category: .import)
            }
        }
    }
    
    private func searchForExtractedArtist(artistName: String?) async throws -> Artist? {
        // Erstelle neuen Künstler
        guard let artistName, !artistName.isEmpty else { return nil }
        var importedArtsit: Artist?
        
        importedArtsit = try await dependencies.artistRepository.searchArtists(query: artistName).first
        
        if importedArtsit == nil {
            let spotifyArtist = try await dependencies.spotifyRepository.searchArtists(query: artistName, limit: 1, offset: 0)
            if let foundSpotifyArtist = spotifyArtist.first {
                importedArtsit = try await dependencies.artistRepository.getOrCreateArtist(CreateArtistDTO(artist: Artist(artist: foundSpotifyArtist)))
            }
        }
        
        return importedArtsit
    }
    
    private func findOrCreateVenue(venueName: String?) async throws -> Venue? {
        guard let venueName, !venueName.isEmpty else { return nil }
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

// MARK: - Apple Intelligence Scanner (iOS 18.2+)

@available(iOS 18.2, *)
extension TicketScannerView {
    
    private func scanWithAppleIntelligence(image: UIImage) async throws -> TicketInfo? {
        // Apple Intelligence API (hypothetisch, da noch nicht final)
        // Dieser Code zeigt wie es funktionieren könnte
        
        guard let cgImage = image.cgImage else {
            throw TicketScanError.invalidImage
        }
        
        // Create request for Apple Intelligence
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US"]
        
        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            return nil
        }
        
        // Extract all text
        var allText = ""
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            allText += candidate.string + "\n"
        }
        
        // Use NLP to extract structured data
        return try await extractStructuredData(from: allText, image: image)
    }
    
    private func extractStructuredData(from text: String, image: UIImage) async throws -> TicketInfo {
        // Use Natural Language Processing
        let parser = TicketTextParser()
        return try parser.parse(text: text)
    }
}

// MARK: - Vision OCR Scanner

extension TicketScannerView {
    
    private func scanWithVisionOCR(image: UIImage) async throws -> TicketInfo {
        guard let cgImage = image.cgImage else {
            throw TicketScanError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create Vision request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: TicketScanError.noTextFound)
                    return
                }
                
                // Extract text from observations
                var extractedText = ""
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    extractedText += candidate.string + "\n"
                }
                
                // Parse text
                let parser = TicketTextParser()
                do {
                    let info = try parser.parse(text: extractedText)
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // Configure request for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "en-US"]
            
            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Models

struct TicketInfo: Equatable, Hashable {
    var artistName: String = ""
    var venueName: String?
    var city: String?
    var date: Date?
    var price: String?
    var seatInfo: String?
    var ticketProvider: String?
    
    var artist: Artist?
    var venue: Venue?
}

enum TicketScanError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case noArtistFound
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Ungültiges Bild"
        case .noTextFound:
            return "Kein Text im Bild gefunden"
        case .noArtistFound:
            return "Konnte Künstlernamen nicht erkennen"
        case .parsingFailed:
            return "Konnte Ticket-Informationen nicht extrahieren"
        }
    }
}

// MARK: - Preview

#Preview {
    TicketScannerView()
}

@Observable
class CameraManager {
    var permissionGranted = false
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: {accessGranted in
            DispatchQueue.main.async {
                self.permissionGranted = accessGranted
            }
        })
    }
}
