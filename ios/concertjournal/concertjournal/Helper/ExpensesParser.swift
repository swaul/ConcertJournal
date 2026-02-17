//
//  ExpensesParser.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

struct ExpensesParser {

    /// Parse price strings like "38,99 €", "€ 49.99", "$150", "25.50 EUR"
    static func parse(_ input: String) -> PriceDTO? {
        let cleaned = input.replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Extract number (support both , and . as decimal separator)
        guard let value = extractValue(from: cleaned) else {
            return nil
        }

        // Extract currency
        let currency = extractCurrency(from: cleaned)

        return PriceDTO(value: value, currency: currency)
    }

    private static func extractValue(from string: String) -> Decimal? {
        // Replace comma with dot for decimal parsing
        let normalized = string.replacingOccurrences(of: ",", with: ".")

        // Pattern to find numbers with optional decimal point
        let pattern = #"(\d+\.?\d*)"#
        guard let match = normalized.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let numberString = String(normalized[match])
        return Decimal(string: numberString)
    }

    private static func extractCurrency(from string: String) -> String {
        // Common currency symbols and codes
        let currencies = [
            ("€", "EUR"),
            ("$", "USD"),
            ("£", "GBP"),
            ("¥", "JPY"),
            ("CHF", "CHF"),
            ("EUR", "EUR"),
            ("USD", "USD"),
            ("GBP", "GBP")
        ]

        for (symbol, code) in currencies {
            if string.contains(symbol) {
                return code
            }
        }

        // Default to EUR for German app
        return "EUR"
    }
}
