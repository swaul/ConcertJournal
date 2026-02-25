//
//  TourSyncManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 25.02.26.
//

import Foundation
import Supabase
import CoreData

protocol TourSyncManagerProtocol {
    func fetchTours() async throws -> [FullTourVisit]
    func fetchTour(id: String) async throws -> FullTourVisit
    func createTour(_ tour: CreateTourDTO) async throws -> FullTourVisit
    func updateTour(id: String, updates: UpdateTourDTO) async throws -> FullTourVisit
    func deleteTour(id: String) async throws
    func getTourConcerts(tourId: String) async throws -> [PartialConcertVisit]
}

class TourSyncManager: TourSyncManagerProtocol {

    private let supabaseClient: SupabaseClientManagerProtocol
    private let apiClient: BFFClient
    private let coreData: CoreDataStack

    init(supabaseClient: SupabaseClientManagerProtocol, apiClient: BFFClient, coreData: CoreDataStack) {
        self.supabaseClient = supabaseClient
        self.apiClient = apiClient
        self.coreData = coreData
    }

    // MARK: - Read Operations

    /// Fetch alle Touren des aktuellen Users
    func fetchTours() async throws -> [FullTourVisit] {
        guard let userId = supabaseClient.currentUserId else {
            throw TourRepositoryError.notAuthenticated
        }

        do {
            let tours: [FullTourVisit] = try await apiClient.get("/tours")

            logSuccess("Loaded \(tours.count) tours", category: .repository)
            return tours
        } catch {
            logError("Failed to fetch tours: \(error.localizedDescription)", category: .repository)
            throw error
        }
    }

    /// Fetch einzelne Tour mit Details
    func fetchTour(id: String) async throws -> FullTourVisit {
        do {
            let tour: FullTourVisit = try await apiClient.get("/tours/\(id)")

            logSuccess("Loaded tour: \(tour.name)", category: .repository)
            return tour
        } catch {
            logError("Failed to fetch tour \(id): \(error.localizedDescription)", category: .repository)
            throw error
        }
    }

    /// Hole alle Konzerte einer Tour
    func getTourConcerts(tourId: String) async throws -> [PartialConcertVisit] {
        do {
            let concerts: [PartialConcertVisit] = try await apiClient.get("/tours/\(tourId)/concerts")

            logSuccess("Loaded \(concerts.count) concerts for tour", category: .repository)
            return concerts
        } catch {
            logError("Failed to fetch tour concerts: \(error.localizedDescription)", category: .repository)
            throw error
        }
    }

    // MARK: - Write Operations

    /// Erstelle neue Tour
    func createTour(_ tour: CreateTourDTO) async throws -> FullTourVisit {
        guard let userId = supabaseClient.currentUserId else {
            throw TourRepositoryError.notAuthenticated
        }

        do {
            var tourPayload = tour
            tourPayload.ownerId = userId.uuidString

            let createdTour: FullTourVisit = try await apiClient.post("/tours", body: tourPayload)

            logSuccess("Created tour: \(createdTour.name)", category: .repository)

            let context = coreData.viewContext

            let request: NSFetchRequest<Tour> = NSFetchRequest()
            request.predicate = NSPredicate(format: "name == %@", tour.name)
            request.fetchLimit = 1

            if let localTour = try? context.fetch(request).first {
                localTour.syncStatus = SyncStatus.synced.rawValue
                localTour.syncVersion = 1
                localTour.lastSyncedAt = Date.now
                
                try context.save()
            }

            return createdTour
        } catch {
            logError("Failed to create tour: \(error.localizedDescription)", category: .repository)
            throw error
        }
    }

    /// Update bestehende Tour
    func updateTour(id: String, updates: UpdateTourDTO) async throws -> FullTourVisit {
        do {
            let updatedTour: FullTourVisit = try await apiClient.put("/tours", body: updates)

            logSuccess("Updated tour: \(updatedTour.name)", category: .repository)
            return updatedTour
        } catch {
            logError("Failed to update tour \(id): \(error.localizedDescription)", category: .repository)
            throw error
        }
    }

    /// Lösche Tour
    func deleteTour(id: String) async throws {
        do {
            try await apiClient.delete("/tours/\(id)")

            logSuccess("Deleted tour: \(id)", category: .repository)
        } catch {
            logError("Failed to delete tour \(id): \(error.localizedDescription)", category: .repository)
            throw error
        }
    }
}

// MARK: - DTOs

struct CreateTourDTO: Codable {
    var name: String
    var tourDescription: String?
    var startDate: String  // ISO 8601
    var endDate: String    // ISO 8601
    var artistId: String?
    var ownerId: String?   // wird vom Repository gesetzt

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

enum TourRepositoryError: LocalizedError {
    case notAuthenticated
    case invalidDateRange
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidDateRange:
            return "End date must be after or equal to start date"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}

