//
//  DurationParser.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

struct DurationParser {

    /// Parse duration strings like "3h 27m", "2 hours 15 minutes", "90m", "1.5h"
    /// Returns: Duration in seconds
    static func parse(_ input: String) -> TimeInterval? {
        let cleaned = input.lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        var totalSeconds: TimeInterval = 0

        // Pattern 1: "3h 27m" or "3 hours 27 minutes"
        let hoursPattern = #"(\d+\.?\d*)\s*(?:h|hours?|stunden?)"#
        let minutesPattern = #"(\d+\.?\d*)\s*(?:m|min|minutes?|minuten?)"#

        // Extract hours
        if let hoursMatch = cleaned.range(of: hoursPattern, options: .regularExpression) {
            let hoursStr = cleaned[hoursMatch]
            if let hours = extractNumber(from: String(hoursStr)) {
                totalSeconds += hours * 3600
            }
        }

        // Extract minutes
        if let minutesMatch = cleaned.range(of: minutesPattern, options: .regularExpression) {
            let minutesStr = cleaned[minutesMatch]
            if let minutes = extractNumber(from: String(minutesStr)) {
                totalSeconds += minutes * 60
            }
        }

        // If nothing found, try to parse as pure number (assume minutes)
        if totalSeconds == 0 {
            if let number = extractNumber(from: cleaned) {
                totalSeconds = number * 60 // Default to minutes
            }
        }

        return totalSeconds > 0 ? totalSeconds : nil
    }

    /// Format seconds back to readable string
    static func format(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private static func extractNumber(from string: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let match = string.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return Double(string[match])
    }
}
