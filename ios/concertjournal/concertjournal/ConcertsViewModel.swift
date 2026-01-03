//
//  ContentView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Combine
import Supabase
import SwiftUI

enum NavigationRoute: Hashable {
    case profile
    case createVisit
    case faq
    case colorPicker
    case concertDetail(FullConcertVisit)
}

class NavigationManager: ObservableObject {
    @Published var path: [NavigationRoute] = []
    
    func push(view: NavigationRoute) {
        path.append(view)
    }
    
    func pop(to target: NavigationRoute? = nil) {
        if let targetIndex = path.firstIndex(where: { $0 == target }) {
            path = []
        } else {
            path = []
        }
    }
}

class ConcertsViewModel: ObservableObject {
    
    @Published var visits = [FullConcertVisit]()
    @Published var futureVisits = [FullConcertVisit]()
    
    init() {
        Task {
            do {
                let results = try await loadData()
                filterFutureConcerts(concerts: results)
            } catch {
                print("could not load concerts, reason:", error)
            }
        }
    }
    
    func filterFutureConcerts(concerts: [FullConcertVisit]) {
        let futureConcerts = concerts.filter { $0.date.timeIntervalSince1970 > Date.now.timeIntervalSince1970 }
        let pastConcerts = concerts.filter { !futureConcerts.contains($0) }
        
        self.visits = pastConcerts
        self.futureVisits = futureConcerts
    }
    
    func reloadData() {
        Task {
            do {
                let results = try await loadData()
                filterFutureConcerts(concerts: results)
            } catch {
                print("could not reload concerts, reason:", error)
            }
        }
    }
    
    func returnTestData() {
        let artist = Artist(name: "Paula Hartmann", imageUrl: "https://i.scdn.co/image/ab6761610000e5eb6db6bdfd82c3394a6af3399e", spotifyArtistId: "3Fl31gc0mEUC2H0JWL1vic")
        let fullVisit = FullConcertVisit(id: "C1", createdAt: .now, updatedAt: .now, date: .now, venue: Venue(id: "V1", name: "Captiol", formattedAddress: "Bär 1, Hannover", latitude: nil, longitude: nil, appleMapsId: nil), city: "Citiycation", rating: 2, title: "This is test data", artist: artist)
        self.visits = [fullVisit]
    }
    
    func loadData() async throws -> [FullConcertVisit] {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
            returnTestData()
            throw NSError(domain: "Auth", code: 401)
        }
        
        let visits: [FullConcertVisit] = try await SupabaseManager.shared.client
            .from("concert_visits")
            .select("""
                id,
                created_at,
                updated_at,
                date,
                venues (
                    id,
                    name,
                    formatted_address,
                    latitude,
                    longitude,
                    apple_maps_id
                ),
                city,
                notes,
                rating,
                title,
                setlist_id,
                artists (
                    id,
                    name,
                    image_url,
                    spotify_artist_id
                )
            """)
            .order("date", ascending: false)
            .execute()
            .value
        
        return visits
    }
}

