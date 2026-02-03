//
//  Travel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

struct Travel: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString

    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let travelExpenses: Price?
    let hotelExpenses: Price?

    // Computed properties for display
    var formattedDuration: String? {
        guard let duration = travelDuration else { return nil }
        return DurationParser.format(duration)
    }

    var formattedDistance: String? {
        guard let distance = travelDistance else { return nil }
        return DistanceParser.format(distance)
    }

    // For Supabase encoding
    enum CodingKeys: String, CodingKey {
        case id
        case travelType = "travel_type"
        case travelDuration = "travel_duration_seconds"
        case travelDistance = "travel_distance_meters"
        case travelExpenses = "travel_expenses"
        case hotelExpenses = "hotel_expenses"
    }
}

enum TravelType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case car
    case plane
    case bike
    case foot
    case train

    var label: String {
        switch self {
        case .car:
            return "Auto"
        case .plane:
            return "Flugzeug"
        case .bike:
            return "Fahrrad"
        case .foot:
            return "zu Fuß"
        case .train:
            return "Zug"
        }
    }
}
