//
//  Photo+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias PhotoCoreDataPropertiesSet = NSSet

extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID
    @NSManaged public var localPath: String?
    @NSManaged public var serverId: String?
    @NSManaged public var serverUrl: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var uploadStatus: String?
    @NSManaged public var concert: Concert?

}

extension Photo : Identifiable {

}
