//
//  Tour+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//
//

public import Foundation
public import CoreData


public typealias TourCoreDataPropertiesSet = NSSet

extension Tour {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tour> {
        return NSFetchRequest<Tour>(entityName: "Tour")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
    @NSManaged public var tourDescription: String?
    @NSManaged public var serverId: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var isOwner: Bool
    @NSManaged public var ownerId: String
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var locallyModifiedAt: Date?
    @NSManaged public var serverModifiedAt: Date?
    @NSManaged public var syncVersion: Int32

    @NSManaged public var artist: Artist
    @NSManaged public var concerts: NSSet?

}

// MARK: Generated accessors for concerts
extension Tour {

    @objc(addConcertsObject:)
    @NSManaged public func addToConcerts(_ value: Concert)

    @objc(removeConcertsObject:)
    @NSManaged public func removeFromConcerts(_ value: Concert)

    @objc(addConcerts:)
    @NSManaged public func addToConcerts(_ values: NSSet)

    @objc(removeConcerts:)
    @NSManaged public func removeFromConcerts(_ values: NSSet)

}

// MARK: - Helper Methods

extension Tour {
    var concertsArray: [Concert] {
        let set = concerts as? Set<Concert> ?? []
        return set.sorted { $0.date < $1.date }
    }

    var concertCount: Int {
        concerts?.count ?? 0
    }

    var duration: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return "\(days + 1) Tage"
    }

    var isOngoing: Bool {
        let now = Date.now
        return startDate <= now && now <= endDate
    }

    var status: TourStatus {
        let now = Date.now
        if now < startDate { return .upcoming }
        else if now > endDate { return .finished }
        else { return .ongoing }
    }
}

public enum TourStatus {
    case upcoming
    case ongoing
    case finished
}

extension Tour: Identifiable {}

extension Tour {

    func toDTO() -> TourDTO {
        TourDTO(id: id.uuidString.lowercased(),
                name: name,
                tourDescription: tourDescription,
                startDate: startDate.supabseDateString,
                endDate: endDate.supabseDateString,
                artistId: artist.serverId ?? artist.id.uuidString.lowercased(),
                ownerId: ownerId)
    }
}
