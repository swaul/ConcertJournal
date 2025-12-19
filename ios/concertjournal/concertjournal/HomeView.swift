//
//  ContentView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Combine
import Supabase
import SwiftUI

struct HomeView: View {
    
    @StateObject private var vm = ConcertsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(vm.visits) { visit in
                        Section(visit.title ?? visit.artist.name) {
                            HStack {
                                AsyncImage(url: URL(string: visit.artist.imageUrl)) { result in
                                    result.image?
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100)
                                }
                                VStack {
                                    Text(visit.artist.name)
                                        .lineLimit(nil)
                                        .foregroundStyle(.white)
                                    if let venue = visit.venue {
                                        Text(venue)
                                            .foregroundStyle(.white)
                                    }
                                    if let city = visit.city {
                                        Text(city)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .background {
                                Color.black
                            }
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Concerts")
        }
    }
    
}

#Preview {
    HomeView()
}

class ConcertsViewModel: ObservableObject {
    @Published var visits = [FullConcertVisit]()
    
    init() {
        Task {
            do {
                let results = try await loadData()
                self.visits = results
            } catch {
                print("could not load concerts")
            }
        }
    }
    
    func loadData() async throws -> [FullConcertVisit] {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { throw NSError(domain: "Auth", code: 401) }
        
        let visits: [FullConcertVisit] = try await SupabaseManager.shared.client
            .from("concert_visits")
            .select("""
                id,
                created_at,
                updated_at,
                date,
                venue,
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
