//
//  SyncManager+FetchOrCreate.swift
//  concertjournal
//
//  Created by Paul Arbetit on 12.03.26.
//

import Foundation
import CoreData

extension SyncManager {
    
    // MARK: - Tour Sync
    
    func fetchOrCreateTourSync(serverId: String, context: NSManagedObjectContext) async throws -> Tour {
        let request: NSFetchRequest<Tour> = Tour.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let loadedTour: TourDTO = try await apiClient.get("/tours/\(serverId)")
        
        let tour = Tour(context: context)
        tour.id = UUID()
        tour.serverId = serverId
        tour.syncStatus = SyncStatus.synced.rawValue
        
        tour.name = loadedTour.name
        tour.artist = try await fetchOrCreateArtistSync(serverId: loadedTour.artistId, context: context)
        
        // TODO: FIX
        tour.startDate = loadedTour.startDate.supabaseStringDate ?? Date.now
        tour.endDate = loadedTour.endDate.supabaseStringDate ?? Date.now
        tour.tourDescription = loadedTour.tourDescription
        
        let currentUserId = await getCurrentUserId()
        tour.ownerId = loadedTour.ownerId
        tour.isOwner = loadedTour.ownerId == currentUserId
        tour.lastSyncedAt = Date.now
        tour.locallyModifiedAt = nil
        tour.syncVersion = 1
        
        return tour
    }
    
    // MARK: - Artist Sync
    
    func fetchOrCreateArtistSync(serverId: String, context: NSManagedObjectContext) async throws -> Artist {
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
    
    // MARK: - Venue Sync
    
    func fetchOrCreateVenueSync(serverId: String, context: NSManagedObjectContext) async throws -> Venue {
        let request: NSFetchRequest<Venue> = Venue.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let loadedVenue: VenueDTO = try await apiClient.get("/venues/\(serverId)")
        
        let venue = Venue(context: context)
        venue.id = UUID()
        venue.serverId = serverId
        venue.syncStatus = SyncStatus.synced.rawValue
        
        venue.name = loadedVenue.name
        venue.city = loadedVenue.city
        venue.formattedAddress = loadedVenue.formattedAddress
        venue.latitude = loadedVenue.latitude ?? 0
        venue.longitude = loadedVenue.longitude ?? 0
        venue.appleMapsId = loadedVenue.appleMapsId
        
        return venue
    }

    
}
