//
//  DistanceParser.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

struct DistanceParser {

    /// Parse distance strings like "346,5km", "250 km", "150 miles", "500m"
    /// Returns: Distance in meters
    static func parse(_ input: String) -> Double? {
        let cleaned = input.lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Extract number
        guard let number = extractNumber(from: cleaned) else {
            return nil
        }

        // Determine unit
        if cleaned.contains("km") {
            return number * 1000 // km to meters
        } else if cleaned.contains("m") && !cleaned.contains("mi") {
            return number // already meters
        } else if cleaned.contains("mi") {
            return number * 1609.34 // miles to meters
        } else {
            // Default to km if no unit specified
            return number * 1000
        }
    }

    /// Format meters back to readable string
    static func format(_ meters: Double, unit: DistanceUnit = .kilometers) -> String {
        switch unit {
        case .meters:
            return String(format: "%.0f m", meters)
        case .kilometers:
            let km = meters / 1000
            if km < 1 {
                return String(format: "%.0f m", meters)
            }
            return String(format: "%.1f km", km)
        case .miles:
            let miles = meters / 1609.34
            return String(format: "%.1f mi", miles)
        }
    }

    enum DistanceUnit {
        case meters
        case kilometers
        case miles
    }

    private static func extractNumber(from string: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let match = string.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return Double(string[match])
    }
}
