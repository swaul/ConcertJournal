//
//  SyncLog+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias SyncLogCoreDataPropertiesSet = NSSet

extension SyncLog {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncLog> {
        return NSFetchRequest<SyncLog>(entityName: "SyncLog")
    }

    @NSManaged public var details: String?
    @NSManaged public var entityId: String?
    @NSManaged public var entityType: String?
    @NSManaged public var errorMessage: String?
    @NSManaged public var id: UUID?
    @NSManaged public var operation: String?
    @NSManaged public var status: String?
    @NSManaged public var timestamp: Date?

}

extension SyncLog : Identifiable {

}
