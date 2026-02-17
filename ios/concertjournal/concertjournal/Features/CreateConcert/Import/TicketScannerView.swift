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
    @State private var extractedText: String?
    @State private var boundingBoxes: [MatchBox] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if cameraManager.permissionGranted {
                    if let image = selectedImage {
                        // Image Preview
                        imageSection(image: image)

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
                            ExtractedTicketInfoCard(info: info, extractedText: extractedText ?? "") { ticketInfo in
                                expotToConcertCreation(info: ticketInfo)
                            }
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
        }
        .background {
            Color.background
        }
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

    @ViewBuilder
    func imageSection(image: UIImage) -> some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geo.size.width,
                       height: geo.size.height)
                .overlay {
                    ForEach(boundingBoxes, id: \.text) { box in

                        let rect = convertBoundingBox(
                            box.boundingBox,
                            imageSize: image.size,
                            containerSize: geo.size
                        )

                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: rect.width,
                                   height: rect.height)
                            .position(
                                x: rect.midX,
                                y: rect.midY
                            )
                    }

                }
        }
        .frame(height: 300)
    }

    func convertBoundingBox(
        _ boundingBox: CGRect,
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {

        let fittedSize = aspectFitSize(
            imageSize: imageSize,
            containerSize: containerSize
        )

        // Offset durch aspectFit (Letterboxing)
        let xOffset = (containerSize.width - fittedSize.width) / 2
        let yOffset = (containerSize.height - fittedSize.height) / 2

        // Vision → Pixel im tatsächlichen Bild
        let width = boundingBox.width * fittedSize.width
        let height = boundingBox.height * fittedSize.height

        let x = boundingBox.origin.x * fittedSize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * fittedSize.height

        return CGRect(
            x: x + xOffset,
            y: y + yOffset,
            width: width,
            height: height
        )
    }

    func aspectFitSize(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGSize {

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
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
                let artist = try await searchForExtractedArtist(artistName: info.artistName)
                let venue = try await findOrCreateVenue(venueName: info.venueName)

                let extendedTicketInfo = ExtendedTicketInfo(ticketInfo: info,
                                                            artist: artist,
                                                            venue: venue)

                navigationManager.push(.createConcertFromTicket(extendedTicketInfo))
            } catch {
                logError("Error with import", error: error, category: .import)
            }
        }
    }
    
    private func searchForExtractedArtist(artistName: String?) async throws -> ArtistDTO? {
        // Erstelle neuen Künstler
        guard let artistName, !artistName.isEmpty else { return nil }
        var importedArtsit: ArtistDTO?

        importedArtsit = try await dependencies.artistRepository.searchArtists(query: artistName).first
        
        if importedArtsit == nil {
            let spotifyArtist = try await dependencies.spotifyRepository.searchArtists(query: artistName, limit: 1, offset: 0)
            if let foundSpotifyArtist = spotifyArtist.first {
                importedArtsit = try await dependencies.artistRepository.getOrCreateArtist(CreateArtistDTO(artist: ArtistDTO(artist: foundSpotifyArtist)))
            }
        }
        
        return importedArtsit
    }

    private func findOrCreateVenue(venueName: String?) async throws -> VenueDTO? {
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
            
            return VenueDTO(id: createdVenueId,
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
        guard let cgImage = image.cgImage else {
            throw TicketScanError.invalidImage
        }

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

        var boundingBoxes = [String: CGRect]()
        // Extract all text
        var allText = ""
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            allText += candidate.string + "\n"
            boundingBoxes[candidate.string] = observation.boundingBox
        }

        self.boundingBoxes = boundingBoxes.map { MatchBox(text: $0.key, boundingBox: $0.value) }
        extractedText = allText

        let biggestText = boundingBoxes.max(by: { $0.value.size.comparableSize > $1.value.size.comparableSize })?.key

        // Use NLP to extract structured data
        return try await extractStructuredData(from: allText, image: image, biggestText: biggestText)
    }
    
    private func extractStructuredData(from text: String, image: UIImage, biggestText: String?) async throws -> TicketInfo {
        // Use Natural Language Processing
        let parser = TicketTextParser(venueRepository: dependencies.venueRepository, biggestText: biggestText)
        return try await parser.parse(text: text)
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

                var boundingBoxes = [String: CGRect]()

                // Extract text from observations
                var extractedText = ""
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    extractedText += candidate.string + "\n"
                    boundingBoxes[extractedText] = observation.boundingBox
                }

                self.extractedText = extractedText

                self.boundingBoxes = boundingBoxes.map { MatchBox(text: $0.key, boundingBox: $0.value) }
                let biggestText = boundingBoxes.max(by: { $0.value.size.comparableSize > $1.value.size.comparableSize })?.key

                // Parse text
                Task {
                    let parser = TicketTextParser(venueRepository: dependencies.venueRepository, biggestText: biggestText)
                    do {
                        let info = try await parser.parse(text: extractedText)
                        continuation.resume(returning: info)
                    } catch {
                        continuation.resume(throwing: error)
                    }
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

struct TicketInfo: Codable, Equatable, Hashable {
    init(artistName: String = "", venueName: String? = nil, city: String? = nil, date: Date? = nil, price: String? = nil, seatInfo: String? = nil, ticketProvider: String? = nil) {
        self.artistName = artistName
        self.venueName = venueName
        self.city = city
        self.date = date
        self.price = price
        self.seatInfo = seatInfo
        self.ticketProvider = ticketProvider
    }

    var artistName: String = ""
    var venueName: String?
    var city: String?
    var date: Date?
    var price: String?
    var seatInfo: String?
    var ticketProvider: String?

    init() {}
}

struct ExtendedTicketInfo: Codable, Equatable, Hashable {
    let artistName: String
    let venueName: String?
    let city: String?
    let date: Date?
    let price: String?
    let seatInfo: String?
    let ticketProvider: String?
    let venue: VenueDTO?
    let artist: ArtistDTO?

    init(ticketInfo: TicketInfo, artist: ArtistDTO?, venue: VenueDTO?) {
        self.artistName = ticketInfo.artistName
        self.venueName = ticketInfo.venueName
        self.city = ticketInfo.city
        self.date = ticketInfo.date
        self.price = ticketInfo.price
        self.seatInfo = ticketInfo.seatInfo
        self.ticketProvider = ticketInfo.ticketProvider

        self.artist = artist
        self.venue = venue
    }
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

extension CGSize {
    var comparableSize: CGFloat {
        self.width + self.height
    }
}

struct MatchBox {
    let text: String
    let boundingBox: CGRect
}
