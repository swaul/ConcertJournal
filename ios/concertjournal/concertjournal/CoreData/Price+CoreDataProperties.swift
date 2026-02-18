//
//  Price+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias PriceCoreDataPropertiesSet = NSSet

extension Price {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Price> {
        return NSFetchRequest<Price>(entityName: "Price")
    }

    @NSManaged public var value: Double
    @NSManaged public var currency: String

}

extension Price : Identifiable {

}

extension Price {

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

extension Price {

    func toDTO() -> PriceDTO {
        PriceDTO(
            value: Decimal(value),
            currency: currency
        )
    }
}
