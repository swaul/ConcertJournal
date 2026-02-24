//
//  Travel+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias TravelCoreDataPropertiesSet = NSSet

extension Travel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Travel> {
        return NSFetchRequest<Travel>(entityName: "Travel")
    }

    @NSManaged public var travelType: String?
    @NSManaged public var travelDuration: Double
    @NSManaged public var travelDistance: Double
    @NSManaged public var arrivedAt: Date?
    @NSManaged public var travelExpensesValue: NSDecimalNumber?
    @NSManaged public var travelExpensesCurrency: String?
    @NSManaged public var hotelExpensesValue: NSDecimalNumber?
    @NSManaged public var hotelExpensesCurrency: String?

}

extension Travel : Identifiable {

}

// MARK: - Prices
extension Travel {
    public var travelExpenses: PriceDTO? {
        guard let value = travelExpensesValue, let currency = travelExpensesCurrency else { return nil }
        return PriceDTO(value: value.decimalValue, currency: currency)
    }

    public var hotelExpenses: PriceDTO? {
        guard let value = hotelExpensesValue, let currency = hotelExpensesCurrency else { return nil }
        return PriceDTO(value: value.decimalValue, currency: currency)
    }
}

extension Travel {
    public var travelTypeEnum: TravelType? {
        guard let travelType else { return nil }
        return TravelType(rawValue: travelType)
    }
}

extension Travel {

    func toDTO() -> TravelDTO? {
        TravelDTO(
            travelType: travelTypeEnum,
            travelDuration: travelDuration,
            travelDistance: travelDistance,
            arrivedAt: arrivedAt,
            travelExpenses: travelExpenses,
            hotelExpenses: hotelExpenses
        )
    }
}
