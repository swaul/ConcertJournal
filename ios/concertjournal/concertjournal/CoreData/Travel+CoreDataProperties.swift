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
    @NSManaged public var travelExpenses: Price?
    @NSManaged public var hotelExpenses: Price?

}

extension Travel : Identifiable {

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
            travelExpenses: travelExpenses?.toDTO(),
            hotelExpenses: hotelExpenses?.toDTO()
        )
    }
}
