//
//  Ticket+CoreDataProperties.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//
//

public import Foundation
public import CoreData


public typealias TicketCoreDataPropertiesSet = NSSet

extension Ticket {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Ticket> {
        return NSFetchRequest<Ticket>(entityName: "Ticket")
    }

    @NSManaged public var ticketType: String
    @NSManaged public var ticketCategory: String
    @NSManaged public var seatBlock: String?
    @NSManaged public var seatRow: String?
    @NSManaged public var seatNumber: String?
    @NSManaged public var standingPosition: String?
    @NSManaged public var notes: String?
    @NSManaged public var ticketPrice: Price?

}

extension Ticket : Identifiable {

}

extension Ticket {
    public var ticketTypeEnum: TicketType? {
        TicketType(rawValue: ticketType)
    }
}

extension Ticket {
    public var ticketCategoryEnum: TicketCategory? {
        TicketCategory(rawValue: ticketCategory)
    }
}

extension Ticket {

    func toDTO() -> TicketDTO? {
        guard let ticketType = ticketTypeEnum else { return nil }

        return TicketDTO(
            ticketType: ticketType,
            ticketCategory: ticketCategoryEnum ?? .regular,
            ticketPrice: ticketPrice?.toDTO(),
            seatBlock: seatBlock,
            seatRow: seatRow,
            seatNumber: seatNumber,
            standingPosition: standingPosition,
            notes: notes
        )
    }
}
