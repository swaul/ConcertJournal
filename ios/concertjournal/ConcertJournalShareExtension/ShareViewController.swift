//
//  ShareViewController.swift
//  ConcertJournalShareExtension
//
//  Share Extension für Konzert-Import aus Ticketmaster, Eventim, etc.
//

import Social
import UniformTypeIdentifiers
import UIKit

class ShareViewController: UIViewController {

    // MARK: - UI Components

    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .label
        return spinner
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Konzert importieren", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 17)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.isHidden = true
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Abbrechen", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        return button
    }()

    // MARK: - Properties

    private var extractedConcert: ExtractedConcertInfo?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add subviews
        view.addSubview(loadingView)
        loadingView.addSubview(spinner)
        loadingView.addSubview(statusLabel)
        view.addSubview(importButton)
        view.addSubview(cancelButton)

        // Layout
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        importButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -30),

            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            importButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            importButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            importButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Actions
        importButton.addTarget(self, action: #selector(importConcert), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        spinner.startAnimating()
    }

    // MARK: - Content Processing

    private func processSharedContent() {
        statusLabel.text = "Suche Konzertinformationen..."

        guard let extensionContext = extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem] else {
            showError("Keine Daten gefunden")
            return
        }

        // Process all items
        for item in items {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Check for URL
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                        if let url = data as? URL {
                            self?.processURL(url)
                        } else if let data = data as? Data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                            self?.processURL(url)
                        }
                    }
                }

                // Check for plain text (sometimes URLs come as text)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                        if let text = data as? String {
                            self?.processText(text)
                        }
                    }
                }
            }
        }
    }

    private func processURL(_ url: URL) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Analysiere Link..."
        }

        // Detect platform and extract info
        let extractor = ConcertLinkExtractor()

        Task {
            do {
                let concert = try await extractor.extractConcertInfo(from: url)
                await MainActor.run {
                    self.showConcertPreview(concert)
                }
            } catch {
                await MainActor.run {
                    self.showError("Konnte keine Konzertinformationen finden: \(error.localizedDescription)")
                }
            }
        }
    }

    private func processText(_ text: String) {
        // Try to find URLs in text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if let match = matches?.first, let url = match.url {
            processURL(url)
        } else {
            // Try to parse text for concert info
            let extractor = ConcertLinkExtractor()
            if let concert = extractor.extractFromText(text) {
                showConcertPreview(concert)
            } else {
                showError("Keine Konzertinformationen gefunden")
            }
        }
    }

    // MARK: - UI Updates

    private func showConcertPreview(_ concert: ExtractedConcertInfo) {
        self.extractedConcert = concert

        spinner.stopAnimating()
        loadingView.isHidden = true
        importButton.isHidden = false

        // Update UI with concert info
        var info = "🎵 \(concert.artistName)\n"
        if let venue = concert.venueName {
            info += "📍 \(venue)\n"
        }
        if let city = concert.city {
            info += "🏙️ \(city)\n"
        }
        if let date = concert.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            info += "📅 \(formatter.string(from: date))\n"
        }
        if let price = concert.price {
            info += "💰 \(price)\n"
        }
        if let platform = concert.platform {
            info += "🎫 via \(platform)"
        }

        statusLabel.text = info
    }

    private func showError(_ message: String) {
        spinner.stopAnimating()
        statusLabel.text = "❌ \(message)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.cancel()
        }
    }

    // MARK: - Actions

    @objc private func importConcert() {
        guard let concert = extractedConcert else { return }

        // Save to shared container
        saveConcertToSharedContainer(concert)

        // Open main app with deep link
        openMainApp()
    }

    @objc private func cancel() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    // MARK: - Data Sharing

    private func saveConcertToSharedContainer(_ concert: ExtractedConcertInfo) {
        guard let sharedContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.de.kuehnel.concertjournal"
        ) else {
            print("Failed to access shared container")
            return
        }

        let fileURL = sharedContainer.appendingPathComponent("pending_import.json")

        do {
            let data = try JSONEncoder().encode(concert)
            try data.write(to: fileURL)
            print("Saved concert to shared container: \(fileURL)")
        } catch {
            print("Failed to save concert: \(error)")
        }
    }

    private func openMainApp() {
        // Open main app with deep link
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                let url = URL(string: "concertjournal://import-concert")!
                application.open(url)
                break
            }
            responder = responder?.next
        }

        // Complete extension
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Extracted Concert Info Model

public struct ExtractedConcertInfo: Codable {
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

// MARK: - Concert Link Extractor

class ConcertLinkExtractor {

    func extractConcertInfo(from url: URL) async throws -> ExtractedConcertInfo {
        let urlString = url.absoluteString.lowercased()

        // Detect platform
        if urlString.contains("eventim.de") {
            return try await extractFromEventim(url)
        } else if urlString.contains("ticketmaster.de") || urlString.contains("ticketmaster.com") {
            return try await extractFromTicketmaster(url)
        } else if urlString.contains("eventbrite") {
            return try await extractFromEventbrite(url)
        } else {
            throw ExtractionError.unsupportedPlatform
        }
    }

    func extractFromText(_ text: String) -> ExtractedConcertInfo? {
        // Extract artist name from text like "HE/RO - Tickets gibt es bei EVENTIM!"
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Remove ticket platform mentions
            var artistName = line
                .replacingOccurrences(of: " - Tickets gibt es bei EVENTIM!", with: "")
                .replacingOccurrences(of: " - Tickets", with: "")
                .trimmingCharacters(in: .whitespaces)

            if !artistName.isEmpty && artistName.count < 100 {
                // Try to find URL in text for more info
                if let url = findURL(in: text) {
                    return ExtractedConcertInfo(
                        artistName: artistName,
                        venueName: nil,
                        city: nil,
                        date: nil,
                        price: nil,
                        platform: detectPlatform(from: text),
                        originalURL: url.absoluteString,
                        eventID: nil,
                        imageURL: nil
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Eventim Extraction

    private func extractFromEventim(_ url: URL) async throws -> ExtractedConcertInfo {
        // Extract event ID from URL
        let eventID = extractEventimEventID(from: url)

        // Fetch event details from Eventim API or scrape
        let html = try await fetchHTML(from: url)

        return ExtractedConcertInfo(
            artistName: extractEventimArtist(from: html),
            venueName: extractEventimVenue(from: html),
            city: extractEventimCity(from: html),
            date: extractEventimDate(from: html),
            price: extractEventimPrice(from: html),
            platform: "Eventim",
            originalURL: url.absoluteString,
            eventID: eventID,
            imageURL: extractEventimImage(from: html)
        )
    }

    private func extractEventimEventID(from url: URL) -> String? {
        // Example: https://www.eventim.de/event/21322444
        let components = url.pathComponents
        return components.last
    }

    private func extractEventimArtist(from html: String) -> String {
        // Extract artist from meta tags or title
        if let artistMatch = html.range(of: #"<meta property="og:title" content="([^"]+)""#, options: .regularExpression) {
            let content = String(html[artistMatch])
            if let nameMatch = content.range(of: #"content="([^"]+)""#, options: .regularExpression) {
                let name = String(content[nameMatch])
                    .replacingOccurrences(of: #"content=""#, with: "")
                    .replacingOccurrences(of: #"""#, with: "")
                    .components(separatedBy: " - ").first ?? ""
                return name
            }
        }
        return "Unknown Artist"
    }

    private func extractEventimVenue(from html: String) -> String? {
        // Extract venue from structured data or meta tags
        if let venueMatch = html.range(of: #""location":\s*\{"name":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[venueMatch])
            if let name = match.components(separatedBy: #"name":""#).last?.components(separatedBy: #"""#).first {
                return name
            }
        }
        return nil
    }

    private func extractEventimCity(from html: String) -> String? {
        // Extract city
        if let cityMatch = html.range(of: #""addressLocality":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[cityMatch])
            if let city = match.components(separatedBy: #"addressLocality":""#).last?.components(separatedBy: #"""#).first {
                return city
            }
        }
        return nil
    }

    private func extractEventimDate(from html: String) -> Date? {
        // Extract date from JSON-LD
        if let dateMatch = html.range(of: #""startDate":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[dateMatch])
            if let dateString = match.components(separatedBy: #"startDate":""#).last?.components(separatedBy: #"""#).first {
                let formatter = ISO8601DateFormatter()
                return formatter.date(from: dateString)
            }
        }
        return nil
    }

    private func extractEventimPrice(from html: String) -> String? {
        if let priceMatch = html.range(of: #""price":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[priceMatch])
            if let price = match.components(separatedBy: #"price":""#).last?.components(separatedBy: #"""#).first {
                return price
            }
        }
        return nil
    }

    private func extractEventimImage(from html: String) -> String? {
        if let imageMatch = html.range(of: #"<meta property="og:image" content="([^"]+)""#, options: .regularExpression) {
            let match = String(html[imageMatch])
            if let url = match.components(separatedBy: #"content=""#).last?.components(separatedBy: #"""#).first {
                return url
            }
        }
        return nil
    }

    // MARK: - Ticketmaster Extraction

    private func extractFromTicketmaster(_ url: URL) async throws -> ExtractedConcertInfo {
        let html = try await fetchHTML(from: url)

        return ExtractedConcertInfo(
            artistName: extractTicketmasterArtist(from: html, url: url),
            venueName: extractTicketmasterVenue(from: html),
            city: extractTicketmasterCity(from: html),
            date: extractTicketmasterDate(from: html),
            price: extractTicketmasterPrice(from: html),
            platform: "Ticketmaster",
            originalURL: url.absoluteString,
            eventID: extractTicketmasterEventID(from: url),
            imageURL: extractTicketmasterImage(from: html)
        )
    }

    private func extractTicketmasterArtist(from html: String, url: URL) -> String {
        // Try from meta tags first
        if let artistMatch = html.range(of: #"<meta property="og:title" content="([^"]+)""#, options: .regularExpression) {
            let content = String(html[artistMatch])
            if let nameMatch = content.range(of: #"content="([^"]+)""#, options: .regularExpression) {
                let name = String(content[nameMatch])
                    .replacingOccurrences(of: #"content=""#, with: "")
                    .replacingOccurrences(of: #"""#, with: "")
                    .components(separatedBy: " Tickets").first ?? ""
                if !name.isEmpty {
                    return name
                }
            }
        }

        // Fallback: Extract from URL path
        // Example: /artist/the-weeknd-tickets/884434
        let components = url.pathComponents
        if let artistIndex = components.firstIndex(of: "artist"),
           artistIndex + 1 < components.count {
            let slug = components[artistIndex + 1]
                .replacingOccurrences(of: "-tickets", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            return slug
        }

        return "Unknown Artist"
    }

    private func extractTicketmasterVenue(from html: String) -> String? {
        if let venueMatch = html.range(of: #""name":"([^"]+)","type":"venue""#, options: .regularExpression) {
            let match = String(html[venueMatch])
            if let name = match.components(separatedBy: #"name":""#).last?.components(separatedBy: #"""#).first {
                return name
            }
        }
        return nil
    }

    private func extractTicketmasterCity(from html: String) -> String? {
        if let cityMatch = html.range(of: #""city":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[cityMatch])
            if let city = match.components(separatedBy: #"city":""#).last?.components(separatedBy: #"""#).first {
                return city
            }
        }
        return nil
    }

    private func extractTicketmasterDate(from html: String) -> Date? {
        if let dateMatch = html.range(of: #""localDate":"([^"]+)""#, options: .regularExpression) {
            let match = String(html[dateMatch])
            if let dateString = match.components(separatedBy: #"localDate":""#).last?.components(separatedBy: #"""#).first {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: dateString)
            }
        }
        return nil
    }

    private func extractTicketmasterPrice(from html: String) -> String? {
        if let priceMatch = html.range(of: #""min":([0-9.]+)"#, options: .regularExpression) {
            let match = String(html[priceMatch])
            if let price = match.components(separatedBy: #"min":"#).last?.components(separatedBy: #"""#).first {
                return "ab \(price)€"
            }
        }
        return nil
    }

    private func extractTicketmasterEventID(from url: URL) -> String? {
        // Example: /event/123456
        let components = url.pathComponents
        return components.last
    }

    private func extractTicketmasterImage(from html: String) -> String? {
        if let imageMatch = html.range(of: #"<meta property="og:image" content="([^"]+)""#, options: .regularExpression) {
            let match = String(html[imageMatch])
            if let url = match.components(separatedBy: #"content=""#).last?.components(separatedBy: #"""#).first {
                return url
            }
        }
        return nil
    }

    // MARK: - Eventbrite Extraction

    private func extractFromEventbrite(_ url: URL) async throws -> ExtractedConcertInfo {
        let html = try await fetchHTML(from: url)

        return ExtractedConcertInfo(
            artistName: extractEventbriteArtist(from: html),
            venueName: extractEventbriteVenue(from: html),
            city: extractEventbriteCity(from: html),
            date: extractEventbriteDate(from: html),
            price: extractEventbritePrice(from: html),
            platform: "Eventbrite",
            originalURL: url.absoluteString,
            eventID: nil,
            imageURL: nil
        )
    }

    private func extractEventbriteArtist(from html: String) -> String {
        if let artistMatch = html.range(of: #"<meta property="og:title" content="([^"]+)""#, options: .regularExpression) {
            let content = String(html[artistMatch])
            if let name = content.components(separatedBy: #"content=""#).last?.components(separatedBy: #"""#).first {
                return name
            }
        }
        return "Unknown Artist"
    }

    private func extractEventbriteVenue(from html: String) -> String? {
        return nil // Implement if needed
    }

    private func extractEventbriteCity(from html: String) -> String? {
        return nil // Implement if needed
    }

    private func extractEventbriteDate(from html: String) -> Date? {
        return nil // Implement if needed
    }

    private func extractEventbritePrice(from html: String) -> String? {
        return nil // Implement if needed
    }

    // MARK: - Helpers

    private func fetchHTML(from url: URL) async throws -> String {
        print("Trying to handle url: \(url.absoluteString)")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ExtractionError.invalidHTML
        }
        return html
    }

    private func findURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url
    }

    private func detectPlatform(from text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("eventim") { return "Eventim" }
        if lowercased.contains("ticketmaster") { return "Ticketmaster" }
        if lowercased.contains("eventbrite") { return "Eventbrite" }
        return nil
    }
}

// MARK: - Errors

enum ExtractionError: Error {
    case unsupportedPlatform
    case invalidHTML
    case missingInformation
}
