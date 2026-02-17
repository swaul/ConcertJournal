//
//  Venue+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias VenueCoreDataPropertiesSet = NSSet

extension Venue {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Venue> {
        return NSFetchRequest<Venue>(entityName: "Venue")
    }

    @NSManaged public var id: UUID
    @NSManaged public var city: String?
    @NSManaged public var name: String
    @NSManaged public var serverId: String
    @NSManaged public var formattedAddress: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var appleMapsId: String?

}

extension Venue : Identifiable {

}
