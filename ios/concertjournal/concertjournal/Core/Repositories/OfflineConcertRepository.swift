//
//  OfflineConcertRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import CoreData
import Combine

protocol OfflineConcertRepositoryProtocol {
    func fetchConcerts() -> [Concert]
    func fetchConcertsWithArtist(_ id: UUID) -> [Concert]
    func getConcert(id: UUID) -> Concert?
    func createConcert(_ dto: CreateConcertDTO) throws -> Concert
    func updateConcert(_ concert: Concert, with dto: ConcertUpdate) throws
    func deleteConcert(_ concert: Concert) throws
    func presaveArtist(_ newArtist: ArtistDTO) throws -> Artist
    func sync() async throws
}

class OfflineConcertRepository: OfflineConcertRepositoryProtocol {

    private let coreData = CoreDataStack.shared
    private let syncManager: SyncManager

    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }

    // MARK: - Fetch (Always from Core Data)

    func fetchConcerts() -> [Concert] {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Only show non-deleted concerts
        request.predicate = NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue)

        // Sort by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching concerts: \(error)")
            return []
        }
    }

    func fetchConcertsWithArtist(_ id: UUID) -> [Concert] {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Only show non-deleted concerts
        request.predicate = NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue)

        // Sort by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        do {
            return try context.fetch(request).filter { $0.artist.id == id }
        } catch {
            print("Error fetching concerts: \(error)")
            return []
        }
    }

    func getConcert(id: UUID) -> Concert? {
        let context = coreData.viewContext
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching concert: \(error)")
            return nil
        }
    }

    // MARK: - Create (Local First)

    func createConcert(_ dto: CreateConcertDTO) throws -> Concert {
        let context = coreData.viewContext

        // 1. Create in Core Data
        let concert = Concert(context: context)
        concert.id = UUID()
        concert.title = dto.title
        concert.date = dto.date
        concert.notes = dto.notes
        concert.rating = Int16(dto.rating ?? 0)
        concert.city = dto.city

        // Set sync metadata
        concert.syncStatus = SyncStatus.pending.rawValue
        concert.locallyModifiedAt = Date()
        concert.syncVersion = 1
        concert.ownerId = getCurrentUserId()
        concert.isOwner = true
        concert.canEdit = true

        // Set artist & venue (fetch or create)
        concert.artist = fetchOrCreateArtist(id: dto.artistId, context: context)

        if let venueId = dto.venue?.id {
            concert.venue = fetchOrCreateVenue(id: venueId, context: context)
        }

        // 2. Save to Core Data
        try coreData.saveWithResult()

        // 3. Queue for sync
        Task {
            await syncManager.syncConcert(concert)
        }

        return concert
    }

    // MARK: - Update (Local First)

    func updateConcert(_ concert: Concert, with dto: ConcertUpdate) throws {
        let context = coreData.viewContext

        // Check permission
        guard concert.canEdit else {
            throw RepositoryError.noPermission
        }

        // 1. Update in Core Data
        if let title = dto.title {
            concert.title = title
        }

        concert.date = dto.date

        if let notes = dto.notes {
            concert.notes = notes
        }

        if let rating = dto.rating {
            concert.rating = Int16(rating)
        }

        // Update sync metadata
        concert.syncStatus = SyncStatus.pending.rawValue
        concert.locallyModifiedAt = Date()
        concert.syncVersion += 1

        // 2. Save to Core Data
        try coreData.saveWithResult()

        // 3. Queue for sync
        Task {
            await syncManager.syncConcert(concert)
        }
    }

    func presaveArtist(_ newArtist: ArtistDTO) throws -> Artist {
        let context = coreData.viewContext

        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", newArtist.id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let artist = Artist(context: context)
        artist.id = UUID()
        artist.name = newArtist.name
        artist.spotifyArtistId = newArtist.spotifyArtistId
        artist.imageUrl = newArtist.imageUrl

        // 2. Save to Core Data
        try coreData.saveWithResult()

        return artist
    }

    // MARK: - Delete (Soft Delete)

    func deleteConcert(_ concert: Concert) throws {
        let context = coreData.viewContext

        // Check permission
        guard concert.canEdit else {
            throw RepositoryError.noPermission
        }

        // 1. Mark as deleted (soft delete)
        concert.syncStatus = SyncStatus.deleted.rawValue
        concert.locallyModifiedAt = Date()

        // 2. Save
        try coreData.saveWithResult()

        // 3. Queue for sync (will delete on server)
        Task {
            await syncManager.syncConcert(concert)
        }
    }

    // MARK: - Sync

    func sync() async throws {
        try await syncManager.fullSync()
    }

    // MARK: - Helpers
    private func fetchOrCreateArtist(id: String, context: NSManagedObjectContext) -> Artist {
        // 1. Try to fetch existing
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        // 2. Create new if not found
        let artist = Artist(context: context)
        artist.id = UUID()
        artist.serverId = id
        // Note: Will be populated by sync later

        return artist
    }

    private func fetchOrCreateVenue(id: String, context: NSManagedObjectContext) -> Venue {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", id)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let venue = Venue(context: context)
        venue.id = UUID()
        venue.serverId = id

        return venue
    }

    private func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? "unknown"
    }
}

enum RepositoryError: Error {
    case noPermission
    case syncFailed
    case conflictDetected
}
