//
//  CreateConcertVisitViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import Supabase
import Combine
import Foundation
import UIKit

class CreateConcertVisitViewModel: ObservableObject, Hashable, Equatable {
    static func == (lhs: CreateConcertVisitViewModel, rhs: CreateConcertVisitViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: String
    @Published var artist: Artist?
    
    let imageUploader = ImageUploader()
    
    init() {
        self.id = UUID().uuidString
    }
    
    func createVisit(from new: NewConcertVisit) async throws -> String {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id,
              let artist = artist else {
            print("createVisit: Missing user or artist")
            throw CancellationError()
        }
        
        let existingArtistId: String?
        
        if let spotifyArtistId = artist.spotifyArtistId {
            // Get-or-create artist by spotify_artist_id (must match your DB column type)
            let existingArtists: [Artist] = try await SupabaseManager.shared.client
                .from("artists")
                .select()
                .eq("spotify_artist_id", value: spotifyArtistId)
                .execute()
                .value
            
            existingArtistId = existingArtists.first?.id
        } else {
            let existingArtists: [Artist] = try await SupabaseManager.shared.client
                .from("artists")
                .select()
                .eq("name", value: artist.name)
                .execute()
                .value
            
            existingArtistId = existingArtists.first?.id
        }
        
        let artistId: String
        
        if let existingArtistId {
            artistId = existingArtistId
        } else {
            // Insert artist and prefer returning the inserted row to get canonical id
            let artistData = artist.toData
            let inserted: Artist = try await SupabaseManager.shared.client
                .from("artists")
                .insert(artistData)
                .select()
                .single()
                .execute()
                .value
            
            artistId = inserted.id
        }
        
        // Format date as ISO8601 with fractional seconds in UTC (commonly accepted by Postgres timestamptz)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: new.date)
        
        // NOTE: If your `user_id` column is a UUID type, sending a string is typically fine,
        // but if you have issues, consider mapping to `.string` vs `.uuid` depending on your AnyJSON support.
        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "artist_id": .string(artistId),
            "date": .string(dateString),
            "venue_id": new.venue?.id == nil ? .null : .string(new.venue!.id),
            "city": new.venue?.city == nil ? .null : .string(new.venue!.city!),
            "notes": new.notes.isEmpty ? .null : .string(new.notes),
            "rating": .integer(new.rating),
            "title": new.title.isEmpty ? .null : .string(new.title)
        ]
        
        // Insert visit and log returned value for debugging
        let response = try await SupabaseManager.shared.client
            .from("concert_visits")
            .insert(payload)
            .select()
            .single()
            .execute()
        
        let test = try JSONDecoder().decode(ConcertVisitIdDTO.self, from: response.data)
        return test.id
        // Optional: print the inserted visit for verification
        #if DEBUG
            do {
                let data = try JSONSerialization.data(withJSONObject: response.data, options: [.prettyPrinted])
                if let json = String(data: data, encoding: .utf8) {
                    print("Inserted concert_visits row:\n\(json)")
                }
            } catch {
                print("Debug print of inserted row failed: \(error)")
            }
        #endif
        
    }
    
    func uploadSelectedPhotos(selectedImages: [UIImage], visitId: String) async throws {
        for image in selectedImages {
            try await imageUploader.uploadPhoto(image: image, concertVisitId: visitId)
        }
    }
}

struct ConcertVisitIdDTO: Codable {
    let id: String
}
