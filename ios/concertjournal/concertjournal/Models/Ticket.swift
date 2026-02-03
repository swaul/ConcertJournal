//
//  TicketType.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation
import Supabase

struct Price: Codable, Equatable, SupabaseEncodable {
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

    func encoded() throws -> [String : AnyJSON] {
        let data: [String: AnyJSON] = [
            CodingKeys.currency.rawValue: .string(currency),
            CodingKeys.value.rawValue: .double(value.doubleValue)
        ]

        return data
    }
}

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}

struct Ticket {
    let ticketType: TicketType
    let ticketCategory: TicketCategory
    let ticketPrice: Price

    // Seated Ticket Info
    let seatBlock: String
    let seatRow: String
    let seatNumber: String

    // Standing Ticket info
    let standingPosition: String
}

enum TicketType: String {
    case seated
    case standing
}

enum TicketCategory: String {
    case regular
    case vip
}
