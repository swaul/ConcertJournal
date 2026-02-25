//
//  TourRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import CoreData
import Foundation

protocol OfflineTourRepositoryProtocol {
    func createTour(name: String,
                    startDate: Date,
                    endDate: Date,
                    artist: ArtistDTO,
                    description: String?) async throws -> CreateTourDTO
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
    private let coreDataStack: CoreDataStack
    private let apiClient: BFFClient

    init(coreDataStack: CoreDataStack, apiClient: BFFClient) {
        self.coreDataStack = coreDataStack
        self.apiClient = apiClient
    }

    // MARK: - Create
    func createTour(name: String, startDate: Date, endDate: Date, artist: ArtistDTO, description: String? = nil) async throws -> CreateTourDTO {
        let context = coreDataStack.viewContext
        let tour = Tour(context: context)
        tour.id = UUID()
        tour.name = name
        tour.startDate = startDate
        tour.endDate = endDate
        tour.tourDescription = description
        tour.artist = await fetchOrCreateArtist(from: artist, context: context)
        tour.ownerId = UserDefaults.standard.string(forKey: "userId") ?? "local"
        tour.isOwner = true
        tour.syncStatus = SyncStatus.pending.rawValue
        tour.locallyModifiedAt = Date.now
        tour.syncVersion = 1

        save()

        guard let artistServerId = tour.artist.serverId else { throw SyncError.missingServerId }
        return CreateTourDTO(name: tour.name,
                             tourDescription: tour.tourDescription,
                             startDate: tour.startDate.supabseDateString,
                             endDate: tour.endDate.supabseDateString,
                             artistId: artistServerId,
                             ownerId: tour.ownerId)
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

    private func fetchOrCreateArtist(
        from dto: ArtistDTO,
        context: NSManagedObjectContext
    ) async -> Artist {

        // 1. Server fragen via spotifyId
        if let spotifyId = dto.spotifyArtistId, !spotifyId.isEmpty {
            if let serverArtist: ArtistDTO = try? await apiClient.get("/artists/\(spotifyId)") {
                // Server kennt ihn – lokal nach serverId suchen oder neu anlegen
                if let existing = fetchLocalArtistIfExists(serverArtist: serverArtist, context: context) {
                    return existing
                }

                // Server kennt ihn aber lokal noch nicht → mit serverId anlegen
                let artist = Artist(context: context)
                artist.id = UUID()
                artist.name = serverArtist.name
                artist.imageUrl = serverArtist.imageUrl
                artist.spotifyArtistId = serverArtist.spotifyArtistId
                artist.serverId = serverArtist.id  // ← direkt mit serverId
                artist.syncStatus = SyncStatus.synced.rawValue  // ← schon synced!
                return artist
            }
        }

        // 2. Lokal nach spotifyId suchen (Server offline oder kein spotifyId)
        if let spotifyId = dto.spotifyArtistId, !spotifyId.isEmpty {
            let request: NSFetchRequest<Artist> = Artist.fetchRequest()
            request.predicate = NSPredicate(format: "spotifyArtistId == %@", spotifyId)
            request.fetchLimit = 1
            if let existing = try? context.fetch(request).first {
                return existing
            }
        }

        // 3. Neu anlegen (wirklich unbekannt)
        let artist = Artist(context: context)
        artist.id = UUID()
        artist.name = dto.name
        artist.imageUrl = dto.imageUrl
        artist.spotifyArtistId = dto.spotifyArtistId
        artist.syncStatus = SyncStatus.pending.rawValue
        return artist
    }

    private func fetchLocalArtistIfExists(serverArtist: ArtistDTO, context: NSManagedObjectContext) -> Artist? {
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverArtist.id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        guard let spotifyId = serverArtist.spotifyArtistId, !spotifyId.isEmpty else { return nil }
        request.predicate = NSPredicate(format: "spotifyArtistId == %@", spotifyId)

        if let existing = try? context.fetch(request).first {
            existing.serverId = serverArtist.id
            existing.syncStatus = SyncStatus.synced.rawValue
            return existing
        }

        return nil
    }

}
