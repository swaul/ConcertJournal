//
//  TourSyncManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 25.02.26.
//

import Foundation
import Supabase
import CoreData
import Combine

@Observable
class TourSyncManager {
    
    let coreData = CoreDataStack.shared
    var isSyncing = false
    let apiClient: BFFClient
    
    private let userSessionManager: UserSessionManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(apiClient: BFFClient,
         userSessionManager: UserSessionManagerProtocol) {
        self.apiClient = apiClient
        self.userSessionManager = userSessionManager
    }
    
    // MARK: - Auth Check
    
    /// Prüft, ob der User eingeloggt ist.
    private var isLoggedIn: Bool {
        if case .loggedIn = userSessionManager.state {
            return true
        }
        return false
    }
    
    // MARK: - Full Sync
    
    func fullSync() async throws {
        guard isLoggedIn else {
            logDebug("Skip tour sync – user not logged in", category: .sync)
            return
        }
        
        guard !isSyncing else {
            logDebug("Tour sync already in progress", category: .sync)
            return
        }
        
        isSyncing = true
        NotificationCenter.default.post(name: .tourSyncInProgress, object: nil, userInfo: ["isSyncing": true])
        
        await resetOldErrorStates()
        
        logInfo("Starting full tour sync", category: .sync)
        
        do {
            try await pullChanges()
            try await pushChanges()
        } catch {
            logError("Full tour sync failed", error: error, category: .sync)
            NotificationCenter.default.post(name: .tourSyncInProgress, object: nil, userInfo: ["isSyncing": false])
            throw error
        }
        
        logSuccess("Full tour sync completed", category: .sync)
        isSyncing = false
        NotificationCenter.default.post(name: .tourSyncInProgress, object: nil, userInfo: ["isSyncing": false])
    }
    
    func resetOldErrorStates() async {
        let context = coreData.newBackgroundContext()
        
        await context.perform {
            let request: NSFetchRequest<Tour> = Tour.fetchRequest()
            request.predicate = NSPredicate(
                format: "syncStatus IN %@",
                [SyncStatus.error.rawValue]
            )
            
            for tour in (try? context.fetch(request)) ?? [] {
                tour.syncStatus = SyncStatus.pending.rawValue
            }
            try? context.save()
        }
    }
    
    // MARK: - Individual Tour Sync
    
    func syncTour(_ tour: Tour) async {
        guard isLoggedIn else {
            logDebug("Skip tour sync – user not logged in", category: .sync)
            return
        }
        
        let id = tour.objectID
        let context = coreData.newBackgroundContext()
        
        await context.perform {
            guard let bgTour = try? context.existingObject(with: id) as? Tour else {
                return
            }
            
            switch bgTour.syncStatus {
            case SyncStatus.pending.rawValue:
                Task { try? await self.pushSingleTour(objectID: bgTour.objectID) }
            case SyncStatus.deleted.rawValue:
                Task { try? await self.deleteTourOnServer(objectID: bgTour.objectID) }
            default:
                break
            }
        }
    }
    
    // MARK: - Pull (Server → Core Data)
    
    private func pullChanges() async throws {
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastTourSyncDate") as? Date ?? .distantPast
        
        struct PullResponse: Codable {
            let tours: [ServerTour]
            let deleted: [String]
        }
        
        let response: PullResponse = try await apiClient.get(
            "/tours/sync?since=\(lastSyncDate.ISO8601Format())"
        )
        
        let context = coreData.newBackgroundContext()
        var pulledTours = 0
        
        for serverTour in response.tours {
            do {
                try await mergeTourFromServerSync(serverTour, context: context)
                pulledTours += 1
            } catch {
                logError("Failed to pull tour", error: error)
            }
        }
        
        await context.perform {
            for deletedId in response.deleted {
                self.deleteTourFromServerSync(deletedId, context: context)
            }
            if context.hasChanges {
                try? context.save()
            }
        }
        
        logSuccess("Pulled \(pulledTours) tours", category: .sync)
        
        if pulledTours > 0 {
            coreData.didChange.send()
        }
        
        guard pulledTours == response.tours.count else { return }
        
        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "lastTourSyncDate")
        }
    }
    
    // MARK: - Push (Core Data → Server)
    
    private func pushChanges() async throws {
        let context = coreData.newBackgroundContext()
        
        let pendingIds: [TourSyncInfo] = await context.perform {
            let request: NSFetchRequest<Tour> = Tour.fetchRequest()
            request.predicate = NSPredicate(
                format: "syncStatus IN %@",
                [SyncStatus.pending.rawValue, SyncStatus.deleted.rawValue]
            )
            
            let tours = try? context.fetch(request)
            return tours?.map { tour in
                TourSyncInfo(
                    objectID: tour.objectID,
                    syncStatus: tour.syncStatus ?? "",
                    serverId: tour.serverId
                )
            } ?? []
        }
        
        logInfo("Attempting to push \(pendingIds.count) tour changes", category: .sync)
        
        for info in pendingIds {
            if info.syncStatus == SyncStatus.deleted.rawValue {
                try await deleteTourOnServer(objectID: info.objectID)
            } else {
                try await pushSingleTour(objectID: info.objectID)
            }
        }
        
        logSuccess("Pushed \(pendingIds.count) tour changes", category: .sync)
    }
    
    private func pushSingleTour(objectID: NSManagedObjectID) async throws {
        let context = coreData.newBackgroundContext()
        
        let payload = await context.perform { () -> TourPushPayload? in
            guard let tour = try? context.existingObject(with: objectID) as? Tour else {
                return nil
            }
            return TourPushPayload(tour: tour)
        }
        
        guard var payload else { return }
        
        // Stelle sicher, dass der Artist auf dem Server existiert
        if let artist = payload.artist, payload.artistServerId == nil {
            logInfo("Tour in sync has artist \"\(artist.name)\" which does not exist on the server", category: .sync)
            logInfo("Creating \"\(artist.name)\"", category: .sync)
            let serverArtist: ArtistDTO = try await apiClient.post("/artists", body: CreateArtistDTO(artist: artist))
            logSuccess("Successfully created \"\(artist.name)\"", category: .sync)
            payload.artistServerId = serverArtist.id
            
            await context.perform {
                let request: NSFetchRequest<Artist> = Artist.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND serverId == nil", artist.name)
                request.fetchLimit = 1
                if let localArtist = try? context.fetch(request).first {
                    localArtist.serverId = serverArtist.id
                    localArtist.syncStatus = SyncStatus.synced.rawValue
                    try? context.save()
                }
            }
        }
        
        if let serverId = payload.serverId {
            // Update
            logInfo("Updating Tour \"\(serverId)\"", category: .sync)
            let _: ServerTour = try await apiClient.put("/tours/\(serverId)", body: payload)
        } else {
            logInfo("Creating Tour \"\(payload.name)\"", category: .sync)
            // Create
            let response: ServerTour = try await apiClient.post("/tours", body: payload)
            
            await context.perform {
                if let tour = try? context.existingObject(with: objectID) as? Tour {
                    tour.serverId = response.id
                    tour.syncStatus = SyncStatus.synced.rawValue
                    tour.lastSyncedAt = Date()
                    try? context.save()
                }
            }
        }
        
        await context.perform {
            if let tour = try? context.existingObject(with: objectID) as? Tour {
                tour.syncStatus = SyncStatus.synced.rawValue
                tour.lastSyncedAt = Date()
                try? context.save()
            }
        }
    }
    
    private func deleteTourOnServer(objectID: NSManagedObjectID) async throws {
        let context = coreData.newBackgroundContext()
        
        let serverId = await context.perform { () -> String? in
            guard let tour = try? context.existingObject(with: objectID) as? Tour else {
                return nil
            }
            return tour.serverId
        }
        
        if let serverId {
            try await apiClient.delete("/tours/\(serverId)")
        }
        
        await context.perform {
            if let tour = try? context.existingObject(with: objectID) as? Tour {
                context.delete(tour)
                try? context.save()
            }
        }
    }
    
    // MARK: - Merge (upsert)
    
    private func mergeTourFromServerSync(_ serverTour: ServerTour, context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<Tour> = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverTour.id)
        request.fetchLimit = 1
        
        if let existing = try context.fetch(request).first {
            try await updateTourSync(existing, with: serverTour, context: context)
        } else {
            try await createTourSync(serverTour, context: context)
        }
    }
    
    private func deleteTourFromServerSync(_ serverId: String, context: NSManagedObjectContext) {
        let request: NSFetchRequest<Tour> = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1
        
        guard let tour = try? context.fetch(request).first else { return }
        context.delete(tour)
    }
    
    // MARK: - Update existing Tour
    
    private func updateTourSync(_ tour: Tour, with server: ServerTour, context: NSManagedObjectContext) async throws {
        if tour.syncStatus == SyncStatus.pending.rawValue,
           let serverModified = server.updatedAt,
           let localModified = tour.locallyModifiedAt,
           localModified > serverModified {
            tour.syncStatus = SyncStatus.conflict.rawValue
            logWarning("Conflict for tour: \(tour.name)", category: .sync)
            return
        }
        
        do {
            tour.name = server.name
            tour.tourDescription = server.tourDescription
            tour.startDate = server.startDate
            tour.endDate = server.endDate
            
            if let artistId = server.artistId {
                tour.artist = try await fetchOrCreateArtistSync(serverId: artistId, context: context)
            }
            
            tour.serverModifiedAt = server.updatedAt
            tour.syncStatus = SyncStatus.synced.rawValue
            tour.lastSyncedAt = Date()
        } catch {
            logError("Could not sync tour", error: error)
            throw error
        }
    }
    
    // MARK: - Create new Tour
    
    private func createTourSync(_ server: ServerTour, context: NSManagedObjectContext) async throws {
        let tour = Tour(context: context)
        tour.id = UUID()
        tour.serverId = server.id
        
        tour.name = server.name
        tour.tourDescription = server.tourDescription
        tour.startDate = server.startDate
        tour.endDate = server.endDate
        
        do {
            if let artistId = server.artistId {
                tour.artist = try await fetchOrCreateArtistSync(serverId: artistId, context: context)
            }
            
            let currentUserId = await getCurrentUserId()
            tour.ownerId = server.ownerId
            tour.isOwner = server.ownerId == currentUserId
            
            tour.syncStatus = SyncStatus.synced.rawValue
            tour.lastSyncedAt = Date()
            tour.serverModifiedAt = server.updatedAt
            tour.locallyModifiedAt = Date()
            tour.syncVersion = 1
        } catch {
            logError("Could not create tour from server", error: error)
            throw error
        }
    }
    
    // MARK: - Artist Sync Helper
    
    private func fetchOrCreateArtistSync(serverId: String, context: NSManagedObjectContext) async throws -> Artist {
        let request: NSFetchRequest<Artist> = Artist.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let loadedArtist: ArtistDTO = try await apiClient.get("/artists/\(serverId)")
        
        let artist = Artist(context: context)
        artist.id = UUID()
        artist.serverId = serverId
        artist.syncStatus = SyncStatus.synced.rawValue
        
        artist.name = loadedArtist.name
        artist.imageUrl = loadedArtist.imageUrl
        artist.spotifyArtistId = loadedArtist.spotifyArtistId
        
        return artist
    }
    
    // MARK: - Helpers
    
    func getCurrentUserId() async -> String {
        do {
            return try await userSessionManager.loadUser().id.uuidString.lowercased()
        } catch {
            return "unknown"
        }
    }
}

// MARK: - Push Payload

struct TourPushPayload: Encodable {
    let serverId: String?
    let name: String
    var tourDescription: String?
    let startDate: Date
    let endDate: Date
    let version: Int
    
    let artist: ArtistDTO?
    var artistServerId: String?
    
    private enum CodingKeys: String, CodingKey {
        case serverId = "id"
        case name
        case tourDescription = "tour_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case version
        case artistServerId = "artist_id"
    }
    
    init(tour: Tour) {
        serverId = tour.serverId
        name = tour.name
        tourDescription = tour.tourDescription
        startDate = tour.startDate
        endDate = tour.endDate
        version = Int(tour.syncVersion)
        
        artist = tour.artist.toDTO()
        artistServerId = tour.artist.serverId
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.serverId, forKey: .serverId)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.tourDescription, forKey: .tourDescription)
        try container.encode(self.startDate.supabseDateString, forKey: .startDate)
        try container.encode(self.endDate.supabseDateString, forKey: .endDate)
        try container.encode(self.version, forKey: .version)
        try container.encodeIfPresent(self.artistServerId, forKey: .artistServerId)
    }
}

// MARK: - Sync Helper Structs

struct TourSyncInfo {
    let objectID: NSManagedObjectID
    let syncStatus: String
    let serverId: String?
}

// MARK: - Server Models

struct ServerTour: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date?
    let ownerId: String
    let name: String
    let tourDescription: String?
    let startDate: Date
    let endDate: Date
    let artistId: String?
    let isShared: Bool
    let canEdit: Bool
    let deletedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ownerId = "owner_id"
        case name
        case tourDescription = "tour_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case artistId = "artist_id"
        case isShared = "is_shared"
        case canEdit = "can_edit"
        case deletedAt = "deleted_at"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.ownerId = try container.decode(String.self, forKey: .ownerId)
        self.name = try container.decode(String.self, forKey: .name)
        self.tourDescription = try container.decodeIfPresent(String.self, forKey: .tourDescription)
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        self.isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared) ?? false
        self.canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        
        if let createdAt = try container.decode(String.self, forKey: .createdAt).supabaseStringDate {
            self.createdAt = createdAt
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.createdAt], debugDescription: "Created at missing"))
        }
        
        if let updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)?.supabaseStringDate {
            self.updatedAt = updatedAt
        } else {
            self.updatedAt = nil
        }
        
        if let startDate = try container.decode(String.self, forKey: .startDate).supabaseStringDate {
            self.startDate = startDate
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.startDate], debugDescription: "Start date missing"))
        }
        
        if let endDate = try container.decode(String.self, forKey: .endDate).supabaseStringDate {
            self.endDate = endDate
        } else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.endDate], debugDescription: "End date missing"))
        }
        
        if let deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)?.supabaseStringDate {
            self.deletedAt = deletedAt
        } else {
            self.deletedAt = nil
        }
    }
}

// MARK: - DTOs

struct CreateTourDTO: Codable {
    var name: String
    var tourDescription: String?
    var startDate: String
    var endDate: String
    var artistId: String?
    var ownerId: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case tourDescription = "tour_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case artistId = "artist_id"
        case ownerId = "owner_id"
    }
}

struct UpdateTourDTO: Codable {
    var name: String?
    var tourDescription: String?
    var startDate: String?
    var endDate: String?
    var artistId: String?
    var isShared: Bool?
    var canEdit: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name
        case tourDescription = "tour_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case artistId = "artist_id"
        case isShared = "is_shared"
        case canEdit = "can_edit"
    }
}

// MARK: - Error Handling

enum TourSyncError: Error {
    case missingServerId
    case uploadFailed(String)
    case contextMismatch
}
