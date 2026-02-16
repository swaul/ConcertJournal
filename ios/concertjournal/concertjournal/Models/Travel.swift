//
//  Travel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation
import SwiftUI

struct Travel: Identifiable, Equatable, Codable {
    init?(id: String = UUID().uuidString, travelType: TravelType? = nil, travelDuration: TimeInterval? = nil, travelDistance: Double? = nil, arrivedAt: Date? = nil, travelExpenses: Price? = nil, hotelExpenses: Price? = nil) {
        self.id = id
        self.travelType = travelType
        self.travelDuration = travelDuration
        self.travelDistance = travelDistance
        self.arrivedAt = arrivedAt
        self.travelExpenses = travelExpenses
        self.hotelExpenses = hotelExpenses
        
        guard travelType != nil || travelDuration != nil || travelDistance != nil || travelExpenses != nil || hotelExpenses != nil || arrivedAt != nil else {
            return nil
        }
    }
    
    var id: String = UUID().uuidString

    let travelType: TravelType?
    let travelDuration: TimeInterval?
    let travelDistance: Double?
    let arrivedAt: Date?
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
        case arrivedAt = "arrived_at"
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
    case bus
    case foot
    case train
    case other

    var label: String {
        switch self {
        case .car:
            return "Auto"
        case .plane:
            return "Flugzeug"
        case .bike:
            return "Fahrrad"
        case .bus:
            return "Bus"
        case .foot:
            return "zu Fuß"
        case .train:
            return "Zug"
        case .other:
            return "other"
        }
    }
    
    func infoText(color: Color) -> AttributedString {
        var text: AttributedString

        switch self {
        case .bus:
            text = AttributedString("Du bist mit dem \(label) zur Location gekommen")
        case .car:
            text = AttributedString("Du bist mit dem \(label) zur Location gekommen")
        case .plane:
            text = AttributedString("Du hast für die Reise ein \(label) genommen")
        case .bike:
            text = AttributedString("Du bist mit dem \(label) zur Location gekommen")
        case .foot:
            text = AttributedString("Die Location war \(label) erreichbar")
        case .train:
            text = AttributedString("Du hast den \(label) genommen")
        case .other:
            return "other"
        }

        text.font = .cjBody

        if let range = text.range(of: label) {
            text[range].foregroundColor = color
            text[range].font = .cjHeadline
        }

        return text
    }

}
