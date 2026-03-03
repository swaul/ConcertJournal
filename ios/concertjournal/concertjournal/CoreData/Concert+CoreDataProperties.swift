//
//  Concert+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias ConcertCoreDataPropertiesSet = NSSet

extension Concert {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Concert> {
        return NSFetchRequest<Concert>(entityName: "Concert")
    }

    @NSManaged public var canEdit: Bool
    @NSManaged public var city: String?
    @NSManaged public var date: Date
    @NSManaged public var openingTime: Date?
    @NSManaged public var id: UUID
    @NSManaged public var isOwner: Bool
    @NSManaged public var isShared: Bool
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var locallyModifiedAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var ownerId: String
    @NSManaged public var rating: Int16
    @NSManaged public var serverId: String?
    @NSManaged public var serverModifiedAt: Date?
    @NSManaged public var syncStatus: String?
    @NSManaged public var syncVersion: Int32
    @NSManaged public var title: String?
    @NSManaged public var supportActs: NSSet?
    @NSManaged public var setlistItems: NSSet?
    @NSManaged public var artist: Artist
    @NSManaged public var venue: Venue?
    @NSManaged public var travel: Travel?
    @NSManaged public var ticket: Ticket?
    @NSManaged public var tour: Tour?
    @NSManaged public var images: NSSet?
    @NSManaged public var buddyAttendeesJSON: String?

}

extension Concert : Identifiable {

}

// MARK: - SetlistItems
extension Concert {
    var setlistItemsArray: [SetlistItem] {
        let set = setlistItems as? Set<SetlistItem> ?? []
        return set.sorted { $0.position < $1.position }
    }

    func addSetlistItem(_ item: SetlistItem) {
        let items = self.mutableSetValue(forKey: "setlistItems")
        items.add(item)
    }

    func removeSetlistItem(_ item: SetlistItem) {
        let items = self.mutableSetValue(forKey: "setlistItems")
        items.remove(item)
    }
}

// MARK: - SupportActs
extension Concert {
    var supportActsArray: [Artist] {
        let set = supportActs as? Set<Artist> ?? []
        return set.sorted { $0.name < $1.name }
    }

    func addSupportAct(_ artist: Artist) {
        let supportActs = self.mutableSetValue(forKey: "supportActs")
        supportActs.add(artist)
    }

    func removeSupportAct(_ artist: Artist) {
        let supportActs = self.mutableSetValue(forKey: "supportActs")
        supportActs.remove(artist)
    }
}

// MARK: - Photos
extension Concert {
    var imagesArray: [Photo] {
        let set = images as? Set<Photo> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }

    func addImage(_ image: Photo) {
        let images = self.mutableSetValue(forKey: "images")
        images.add(image)
    }

    func removeImage(_ image: Photo) {
        let images = self.mutableSetValue(forKey: "images")
        images.remove(image)
    }
}

// MARK: - Buddies
extension Concert {
    
    var buddiesArray: [BuddyAttendee] {
        guard let json = buddyAttendeesJSON,
              let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([BuddyAttendee].self, from: data)
        else { return [] }
        return array
    }
    
    func setBuddies(_ attendees: [BuddyAttendee]) {
        buddyAttendeesJSON = try? String(
            data: JSONEncoder().encode(attendees),
            encoding: .utf8
        )
    }
}
