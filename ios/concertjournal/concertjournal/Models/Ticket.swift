//
//  TicketType.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation
import Supabase
import SwiftUI

struct Price: Codable, Equatable {
    let value: Decimal
    let currency: String

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: currency == "EUR" ? "de_DE" : "en_US")

        return formatter.string(from: value as NSNumber) ?? "\(value) \(currency)"
    }

    enum CodingKeys: String, CodingKey {
        case currency
        case value
    }

    // For display in TextField
    var editableString: String {
        "\(value) \(currencySymbol)"
    }

    private var currencySymbol: String {
        switch currency {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        default: return currency
        }
    }
}

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}

struct Ticket: Equatable {

    let ticketType: TicketType
    let ticketCategory: TicketCategory
    let ticketPrice: Price?

    // Seated Ticket Info
    let seatBlock: String?
    let seatRow: String?
    let seatNumber: String?

    // Standing Ticket info
    let standingPosition: String?

    let notes: String?
}

enum TicketType: String, CaseIterable, Codable {
    case seated
    case standing
    
    var label: String {
        switch self {
        case .seated:
            return "Sitzplatz"
        case .standing:
            return "Stehplatz"
        }
    }
}

enum TicketCategory: String, CaseIterable, Codable {
    case regular
    case vip
    case goldenCircle
    case diamondCircle
    
    var label: String {
        switch self {
        case .regular:
            return "Normal"
        case .vip:
            return "V.I.P."
        case .goldenCircle:
            return "Golden Circle"
        case .diamondCircle:
            return "Diamond Circle"
        }
    }
    
    var color: Color {
        switch self {
        case .regular:
            return .green.opacity(0.2)
        case .vip:
            return .red.opacity(0.2)
        case .goldenCircle:
            return .yellow.opacity(0.2)
        case .diamondCircle:
            return .cyan.opacity(0.2)
        }
    }
}
