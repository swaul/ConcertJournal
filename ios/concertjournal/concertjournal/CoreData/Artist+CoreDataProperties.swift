//
//  Artist+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias ArtistCoreDataPropertiesSet = NSSet

extension Artist {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Artist> {
        return NSFetchRequest<Artist>(entityName: "Artist")
    }

    @NSManaged public var id: UUID
    @NSManaged public var imageUrl: String?
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var name: String
    @NSManaged public var serverId: String?
    @NSManaged public var spotifyArtistId: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var concerts: Concert?

}

extension Artist : Identifiable {

}

extension Artist {

    func toDTO() -> ArtistDTO {
        ArtistDTO(id: serverId ?? id.uuidString,
            name: name,
            imageUrl: imageUrl,
            spotifyArtistId: spotifyArtistId
        )
    }
}
