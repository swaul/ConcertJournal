//
//  SetlistItem+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias SetlistItemCoreDataPropertiesSet = NSSet

extension SetlistItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SetlistItem> {
        return NSFetchRequest<SetlistItem>(entityName: "SetlistItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var locallyModifiedAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var position: Int16
    @NSManaged public var section: String?
    @NSManaged public var serverId: String?
    @NSManaged public var spotifyTrackId: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var title: String
    @NSManaged public var albumName: String?
    @NSManaged public var artistNames: String
    @NSManaged public var coverImage: String?
    @NSManaged public var concertId: String
    @NSManaged public var concert: Concert?

}

extension SetlistItem : Identifiable {

}
