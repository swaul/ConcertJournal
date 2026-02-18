//
//  TicketTextParser.swift
//  concertjournal
//
//  Created by Paul Kühnel on 11.02.26.
//

import UIKit
import MapKit

class TicketTextParser {

    let venueRepository: VenueRepositoryProtocol
    let biggestText: String?

    init(venueRepository: VenueRepositoryProtocol, biggestText: String?) {
        self.venueRepository = venueRepository
        self.biggestText = biggestText
    }

    func parse(text: String) async throws -> TicketInfo {
        logInfo("Parsing ticket text...", category: .import)
        logDebug("Text:\n\(text)", category: .import)
        
        var info = TicketInfo()
        
        // Parse artist name (usually at the top, largest text)
        info.artistName = extractArtistName(from: text)
        
        // Parse venue
        info.venueName = try await extractVenueName(from: text)

        // Parse city
        info.city = extractCity(from: text)
        
        // Parse date and time
        if let date = extractDate(from: text) {
            info.date = date
        }
        
        // Parse price
        info.price = extractPrice(from: text)
        
        // Parse seat/section
        info.seatInfo = extractSeatInfo(from: text)
        
        // Parse ticket provider
        info.ticketProvider = extractProvider(from: text)
        
        // Validate that we found at least artist name
        guard !info.artistName.isEmpty else {
            throw TicketScanError.noArtistFound
        }
        
        return info
    }
    
    // MARK: - Extraction Methods
    
    private func extractArtistName(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Common ticket patterns
        let skipKeywords = [
            "ticket", "einlass", "eintrittskarte", "konzert", "show",
            "veranstalter", "datum", "uhrzeit", "doors", "venue",
            "location", "standing", "sitzplatz", "block", "reihe",
            "eventim", "ticketmaster", "reserved", "general admission"
        ]
        
        // Find first line that's not a keyword
        for line in lines {
            let lowercased = line.lowercased()
            
            // Skip if contains common ticket keywords
            if skipKeywords.contains(where: { lowercased.contains($0) }) {
                continue
            }
            
            // Skip if it's a date
            if containsDate(line) {
                continue
            }
            
            // Skip if it's just numbers or very short
            if line.count < 3 || line.allSatisfy({ $0.isNumber }) {
                continue
            }

            if line.isMostlyNumbers {
                continue
            }

            // This is likely the artist name
            return line
        }
        
        // Fallback: return first non-empty line
        return biggestText ?? ""
    }
    
    private func extractVenueName(from text: String) async throws -> String? {
        // Look for venue indicators
        let venueKeywords = ["venue:", "location:", "ort:", "halle:", "arena:", "club:"]
        
        for keyword in venueKeywords {
            if let range = text.range(of: keyword, options: .caseInsensitive) {
                let afterKeyword = String(text[range.upperBound...])
                if let line = afterKeyword.components(separatedBy: .newlines).first {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Look for common venue names
        let venuePatterns = [
            "Arena", "Halle", "Club", "Theater", "Saal",
            "Center", "Stadium", "Dome", "Hall"
        ]
        
        for line in text.components(separatedBy: .newlines) {
            for pattern in venuePatterns {
                if line.contains(pattern) && !line.lowercased().contains("ticket") {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let addressRegex = try? Regex(
            #"^[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß\s\.\-]+?\s\d+[a-zA-Z]?,\s\d{4,5}\s[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß\s\-]+$"#
        ) {
            for line in lines {
                if let match = try? addressRegex.wholeMatch(in: line) {
                    return try await findOrCreateVenue(address: line)?.name
                }
            }
        }

        return nil
    }

    private func findOrCreateVenue(address: String) async throws -> VenueDTO? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .automotiveRepair, .beauty, .evCharger, .mailbox])

        let result = try await MKLocalSearch(request: request).start()
        let bestMatch = result.mapItems.first

        if let bestMatch, let name = bestMatch.name {
            return VenueDTO(id: UUID().uuidString,
                            name: name,
                                       city: bestMatch.addressRepresentations?.cityName,
                                       formattedAddress: bestMatch.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? "",
                                       latitude: bestMatch.location.coordinate.latitude,
                                       longitude: bestMatch.location.coordinate.longitude,
                                       appleMapsId: bestMatch.identifier?.rawValue)
        } else {
            return nil
        }
    }


    private func extractCity(from text: String) -> String? {
        // German cities
        let cities = [
            "Berlin", "Hamburg", "München", "Köln", "Frankfurt am Main",
            "Stuttgart", "Düsseldorf", "Dortmund", "Essen", "Leipzig",
            "Bremen", "Dresden", "Hannover", "Nürnberg", "Duisburg"
        ]
        
        for city in cities {
            if text.contains(city) {
                return city
            }
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let addressRegex = try? Regex(
            #"^(?<street>[A-Za-zÄÖÜäöüß\s\.\-]+?)\s(?<houseNumber>\d+[a-zA-Z]?),\s(?<postalCode>\d{4,5})\s(?<city>[A-Za-zÄÖÜäöüß\s\-]+)$"#
        ) {
            for line in lines {
                if let match = try? addressRegex.wholeMatch(in: line) {
                    let result = match.output.extractValues(as: [String].self)
                    return result?.last
                }
            }
        }

        return nil
    }
    
    private func extractDate(from text: String) -> Date? {
        // Try various date formats
        let dateFormats = [
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "EEEE, dd. MMMM yyyy",
            "dd. MMMM yyyy"
        ]
        
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = dateDetector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first, let date = match.date {
            return date
        }
        
        // Manual parsing
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "de_DE")
            
            for line in text.components(separatedBy: .newlines) {
                if let date = formatter.date(from: line.trimmingCharacters(in: .whitespaces)) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractPrice(from text: String) -> String? {
        // Look for price patterns
        let pricePattern = #"(\d+[,.]?\d*)\s*€"#
        
        if let regex = try? NSRegularExpression(pattern: pricePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            if let match = matches.first,
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func extractSeatInfo(from text: String) -> String? {
        // Look for seat/block/row info
        let patterns = [
            #"Block\s+([A-Z0-9]+)"#,
            #"Reihe\s+(\d+)"#,
            #"Platz\s+(\d+)"#,
            #"Section\s+([A-Z0-9]+)"#,
            #"Row\s+(\d+)"#,
            #"Seat\s+(\d+)"#
        ]
        
        var seatParts: [String] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        seatParts.append(String(text[range]))
                    }
                }
            }
        }
        
        return seatParts.isEmpty ? nil : seatParts.joined(separator: ", ")
    }
    
    private func extractProvider(from text: String) -> String? {
        let providers = ["Eventim", "Ticketmaster", "Eventbrite", "See Tickets", "AXS"]
        
        for provider in providers {
            if text.lowercased().contains(provider.lowercased()) {
                return provider
            }
        }
        
        return nil
    }
    
    private func containsDate(_ text: String) -> Bool {
        let datePatterns = [
            #"\d{1,2}\.\d{1,2}\.\d{4}"#,
            #"\d{1,2}/\d{1,2}/\d{4}"#,
            #"\d{4}-\d{1,2}-\d{1,2}"#
        ]
        
        for pattern in datePatterns {
            if let _ = text.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        
        return false
    }
}

extension String {
    var isMostlyNumbers: Bool {
        let numberCount = self.filter { $0.isNumber }
        return numberCount.count > Int(Double(self.count) * 0.75)
    }
}
