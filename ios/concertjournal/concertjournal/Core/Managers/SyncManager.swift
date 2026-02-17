//
//  SyncManager.swift
//  concertjournal
//
//  ✅ COMPLETELY FIXED: Zero actor isolation warnings
//

import CoreData
import Foundation

class SyncManager {

    private let coreData: CoreDataStack
    private let apiClient: BFFClient
    private var isSyncing = false

    init(apiClient: BFFClient, coreData: CoreDataStack) {
        self.apiClient = apiClient
        self.coreData = coreData
    }

    // MARK: - Full Sync (Pull + Push)

    func fullSync() async throws {
        guard !isSyncing else {
            logDebug("Sync already in progress", category: .sync)
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        logInfo("Starting full sync", category: .sync)

        do {
            try await pullChanges()
            try await pushChanges()

            logSuccess("Full sync completed", category: .sync)

        } catch {
            logError("Full sync failed", error: error, category: .sync)
            throw error
        }
    }

    // MARK: - Pull Changes (Server → Core Data)
    private func pullChanges() async throws {
        logInfo("Pulling changes from server", category: .sync)

        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? .distantPast

        struct PullResponse: Codable {
            let concerts: [ServerConcert]
            let deleted: [String]
        }

        let response: PullResponse = try await apiClient.get(
            "/sync/concerts?since=\(lastSyncDate.ISO8601Format())"
        )

        // ✅ ALL WORK HAPPENS INSIDE context.perform
        let context = coreData.newBackgroundContext()

        try await context.perform {
            // Process all concerts
            for serverConcert in response.concerts {
                try self.mergeConcertFromServerSync(serverConcert, context: context)
            }

            // Delete concerts
            for deletedId in response.deleted {
                self.deleteConcertFromServerSync(deletedId, context: context)
            }

            // Save all changes at once
            if context.hasChanges {
                try context.save()
            }
        }

        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        }

        logSuccess("Pulled \(response.concerts.count) concerts", category: .sync)
    }

    // ✅ SYNC VERSION: Called inside context.perform (NO ACTOR ISOLATION)
    private func mergeConcertFromServerSync(
        _ serverConcert: ServerConcert,
        context: NSManagedObjectContext
    ) throws {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverConcert.id)
        request.fetchLimit = 1

        let existing = try context.fetch(request).first

        if let concert = existing {
            // Update existing
            self.updateConcertSync(concert, with: serverConcert)
        } else {
            // Create new
            self.createConcertSync(serverConcert, context: context)
        }
    }

    // ✅ SYNC VERSION: Direct property access (NO WARNINGS)
    private func updateConcertSync(
        _ concert: Concert,
        with serverConcert: ServerConcert
    ) {
        // Check for conflicts
        if concert.syncStatus == SyncStatus.pending.rawValue {
            if let serverModified = serverConcert.updatedAt,
               concert.locallyModifiedAt! > serverModified {
                // Local is newer → mark conflict
                concert.syncStatus = SyncStatus.conflict.rawValue
                logWarning("Conflict detected for concert: \(concert.title)", category: .sync)
                return
            }
        }

        // ✅ Direct property mutation (works because we're in context.perform)
        concert.title = serverConcert.title
        concert.date = serverConcert.date
        concert.notes = serverConcert.notes
        concert.rating = Int16(serverConcert.rating ?? 0)
        concert.city = serverConcert.city

        concert.serverModifiedAt = serverConcert.updatedAt
        concert.syncStatus = SyncStatus.synced.rawValue
        concert.lastSyncedAt = Date()
    }

    // ✅ SYNC VERSION: Direct property access (NO WARNINGS)
    private func createConcertSync(
        _ serverConcert: ServerConcert,
        context: NSManagedObjectContext
    ) {
        let concert = Concert(context: context)

        // ✅ All property assignments work fine in sync context
        concert.id = UUID()
        concert.serverId = serverConcert.id
        concert.title = serverConcert.title
        concert.date = serverConcert.date
        concert.notes = serverConcert.notes
        concert.rating = Int16(serverConcert.rating ?? 0)
        concert.city = serverConcert.city

        // Get current user ID synchronously
        let currentUserId = Self.getCurrentUserIdStatic()

        concert.ownerId = serverConcert.userId
        concert.isOwner = serverConcert.userId == currentUserId
        concert.canEdit = concert.isOwner

        concert.syncStatus = SyncStatus.synced.rawValue
        concert.lastSyncedAt = Date()
        concert.serverModifiedAt = serverConcert.updatedAt
        concert.locallyModifiedAt = Date()
        concert.syncVersion = 1
    }

    // ✅ SYNC VERSION
    private func deleteConcertFromServerSync(
        _ serverId: String,
        context: NSManagedObjectContext
    ) {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)

        if let concert = try? context.fetch(request).first {
            context.delete(concert)
        }
    }

    // MARK: - Push Changes (Core Data → Server)

    private func pushChanges() async throws {
        logInfo("Pushing changes to server", category: .sync)

        let context = coreData.newBackgroundContext()

        // Fetch pending concert IDs
        let pendingIDs = try await context.perform {
            try self.fetchPendingConcertIDsSync(context: context)
        }

        logDebug("Found \(pendingIDs.count) pending concerts", category: .sync)

        // Sync each concert
        for concertID in pendingIDs {
            await syncConcertToServer(concertID: concertID)
        }
    }

    // ✅ Returns ObjectIDs instead of objects
    private func fetchPendingConcertIDsSync(context: NSManagedObjectContext) throws -> [NSManagedObjectID] {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()
        request.predicate = NSPredicate(
            format: "syncStatus IN %@",
            [SyncStatus.pending.rawValue, SyncStatus.deleted.rawValue]
        )

        let concerts = try context.fetch(request)
        return concerts.map { $0.objectID }
    }

    // MARK: - Sync Single Concert

    func syncConcert(_ concert: Concert) async {
        await syncConcertToServer(concertID: concert.objectID)
    }

    // ✅ Works with ObjectID
    private func syncConcertToServer(concertID: NSManagedObjectID) async {
        let context = coreData.newBackgroundContext()

        do {
            // Get concert info
            let concertInfo = try await context.perform {
                let concert = try context.existingObject(with: concertID) as! Concert

                return ConcertSyncInfo(
                    objectID: concertID,
                    syncStatus: concert.syncStatus!,
                    serverId: concert.serverId
                )
            }

            // Decide what to do based on status
            if concertInfo.syncStatus == SyncStatus.deleted.rawValue {
                try await deleteConcertOnServer(serverId: concertInfo.serverId)

                // Hard delete from Core Data
                try await context.perform {
                    let concert = try context.existingObject(with: concertID) as! Concert
                    context.delete(concert)
                    if context.hasChanges {
                        try context.save()
                    }
                }

            } else if concertInfo.serverId == nil {
                try await createConcertOnServer(concertID: concertID, context: context)

            } else {
                try await updateConcertOnServer(concertID: concertID, context: context)
            }

        } catch {
            await markConcertAsError(concertID: concertID, context: context)
            logError("Sync failed for concert", error: error, category: .sync)
        }
    }

    private func markConcertAsError(concertID: NSManagedObjectID, context: NSManagedObjectContext) async {
        await context.perform {
            if let concert = try? context.existingObject(with: concertID) as? Concert {
                concert.syncStatus = SyncStatus.error.rawValue
                try? context.save()
            }
        }
    }

    // MARK: - Server Operations

    private func createConcertOnServer(concertID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        // ✅ Extract all data first
        let concertData = try await context.perform {
            let concert = try context.existingObject(with: concertID) as! Concert

            return ConcertCreateData(
                title: concert.title,
                date: concert.date,
                notes: concert.notes,
                rating: concert.rating == 0 ? nil : Int(concert.rating),
                city: concert.city
            )
        }

        // Create on server
        struct CreateRequest: Codable {
            let title: String?
            let date: Date
            let notes: String?
            let rating: Int?
            let city: String?
        }

        let request = CreateRequest(
            title: concertData.title,
            date: concertData.date,
            notes: concertData.notes,
            rating: concertData.rating,
            city: concertData.city
        )

        struct CreateResponse: Codable {
            let id: String
            let updatedAt: Date
        }

        let response: CreateResponse = try await apiClient.post("/concerts", body: request)

        // ✅ Update in Core Data
        try await context.perform {
            let concert = try context.existingObject(with: concertID) as! Concert

            concert.serverId = response.id
            concert.serverModifiedAt = response.updatedAt
            concert.syncStatus = SyncStatus.synced.rawValue
            concert.lastSyncedAt = Date()

            if context.hasChanges {
                try context.save()
            }
        }

        logSuccess("Concert created on server: \(response.id)", category: .sync)
    }

    private func updateConcertOnServer(concertID: NSManagedObjectID, context: NSManagedObjectContext) async throws {
        // ✅ Extract all data first
        let concertData = try await context.perform {
            let concert = try context.existingObject(with: concertID) as! Concert

            guard let serverId = concert.serverId else {
                throw SyncError.missingServerId
            }

            return ConcertUpdateData(
                serverId: serverId,
                title: concert.title,
                date: concert.date,
                notes: concert.notes,
                rating: concert.rating == 0 ? nil : Int(concert.rating),
                city: concert.city,
                version: Int(concert.syncVersion)
            )
        }

        // Update on server
        struct UpdateRequest: Codable {
            let title: String?
            let date: Date
            let notes: String?
            let rating: Int?
            let city: String?
            let version: Int
        }

        let request = UpdateRequest(
            title: concertData.title,
            date: concertData.date,
            notes: concertData.notes,
            rating: concertData.rating,
            city: concertData.city,
            version: concertData.version
        )

        struct UpdateResponse: Codable {
            let updatedAt: Date
            let version: Int
        }

        let response: UpdateResponse = try await apiClient.put(
            "/concerts/\(concertData.serverId)",
            body: request
        )

        // ✅ Update sync metadata
        try await context.perform {
            let concert = try context.existingObject(with: concertID) as! Concert

            concert.serverModifiedAt = response.updatedAt
            concert.syncVersion = Int32(response.version)
            concert.syncStatus = SyncStatus.synced.rawValue
            concert.lastSyncedAt = Date()

            if context.hasChanges {
                try context.save()
            }
        }

        logSuccess("Concert updated on server", category: .sync)
    }

    private func deleteConcertOnServer(serverId: String?) async throws {
        guard let serverId = serverId else { return }

        let _: EmptyResponse = try await apiClient.delete("/concerts/\(serverId)")

        logSuccess("Concert deleted on server", category: .sync)
    }

    // MARK: - Helpers

    // ✅ Static helper (no actor isolation)
    private static func getCurrentUserIdStatic() -> String {
        // Get from UserDefaults or singleton
        return UserDefaults.standard.string(forKey: "currentUserId") ?? "unknown"
    }
}

// MARK: - Helper Structs (to pass data out of context.perform)

struct ConcertSyncInfo {
    let objectID: NSManagedObjectID
    let syncStatus: String
    let serverId: String?
}

struct ConcertCreateData {
    let title: String?
    let date: Date
    let notes: String?
    let rating: Int?
    let city: String?
}

struct ConcertUpdateData {
    let serverId: String
    let title: String?
    let date: Date
    let notes: String?
    let rating: Int?
    let city: String?
    let version: Int
}

// MARK: - Errors

enum SyncError: Error {
    case missingServerId
    case contextMismatch
}

// MARK: - Server Models

struct ServerConcert: Codable {
    let id: String
    let userId: String
    let title: String
    let date: Date
    let notes: String?
    let rating: Int?
    let city: String?
    let createdAt: Date
    let updatedAt: Date?
}
