//
//  TourRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import CoreData
import Foundation

protocol OfflineTourRepositoryProtocol {
    func createTour(name: String, startDate: Date, endDate: Date, artist: Artist?, description: String?) -> Tour
    func getAllTours() throws -> [Tour]
    func getToursByArtist(_ artist: Artist) throws -> [Tour]
    func getToursByStatus(_ status: TourStatus) throws -> [Tour]
    func getTour(by id: UUID) throws -> Tour?
    func updateTour(_ tour: Tour, name: String, startDate: Date, endDate: Date, description: String?)
    func addConcertToTour(_ concert: Concert, tour: Tour)
    func removeConcertFromTour(_ concert: Concert)
    func deleteTour(_ tour: Tour) throws
}

class OfflineTourRepository: OfflineTourRepositoryProtocol {
    let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Create
    func createTour(name: String, startDate: Date, endDate: Date, artist: Artist? = nil, description: String? = nil) -> Tour {
        let tour = Tour(context: coreDataStack.viewContext)
        tour.id = UUID()
        tour.name = name
        tour.startDate = startDate
        tour.endDate = endDate
        tour.tourDescription = description
        tour.artist = artist
        tour.ownerId = UserDefaults.standard.string(forKey: "userId") ?? "local"
        tour.isOwner = true
        tour.syncStatus = SyncStatus.pending.rawValue
        tour.locallyModifiedAt = Date.now
        tour.syncVersion = 1

        save()
        return tour
    }

    // MARK: - Read
    func getAllTours() throws -> [Tour] {
        let request = Tour.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tour.startDate, ascending: false)]
        return try coreDataStack.viewContext.fetch(request)
    }

    func getToursByArtist(_ artist: Artist) throws -> [Tour] {
        let request = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "artist == %@", artist)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tour.startDate, ascending: false)]
        return try coreDataStack.viewContext.fetch(request)
    }

    func getToursByStatus(_ status: TourStatus) throws -> [Tour] {
        let request = Tour.fetchRequest()
        let now = Date.now

        switch status {
        case .upcoming:
            request.predicate = NSPredicate(format: "startDate > %@", now as NSDate)
        case .ongoing:
            request.predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", now as NSDate, now as NSDate)
        case .finished:
            request.predicate = NSPredicate(format: "endDate < %@", now as NSDate)
        }

        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tour.startDate, ascending: false)]
        return try coreDataStack.viewContext.fetch(request)
    }

    func getTour(by id: UUID) throws -> Tour? {
        let request = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try coreDataStack.viewContext.fetch(request).first
    }

    // MARK: - Update
    func updateTour(_ tour: Tour, name: String, startDate: Date, endDate: Date, description: String? = nil) {
        tour.name = name
        tour.startDate = startDate
        tour.endDate = endDate
        tour.tourDescription = description
        tour.locallyModifiedAt = Date.now
        tour.syncStatus = SyncStatus.pending.rawValue
        save()
    }

    func addConcertToTour(_ concert: Concert, tour: Tour) {
        concert.tour = tour
        tour.addToConcerts(concert)
        concert.locallyModifiedAt = Date.now
        concert.syncStatus = SyncStatus.pending.rawValue
        save()
    }

    func removeConcertFromTour(_ concert: Concert) {
        concert.tour?.removeFromConcerts(concert)
        concert.tour = nil
        concert.locallyModifiedAt = Date.now
        concert.syncStatus = SyncStatus.pending.rawValue
        save()
    }

    // MARK: - Delete
    func deleteTour(_ tour: Tour) throws {
        // Entferne die Tour-Zuordnung von allen Konzerten
        tour.concertsArray.forEach { concert in
            concert.tour = nil
        }
        coreDataStack.viewContext.delete(tour)
        save()
    }

    // MARK: - Save
    private func save() {
        coreDataStack.save()
    }
}
