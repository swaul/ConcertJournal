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
    case createVisitArtist
    case createVisit(CreateConcertVisitViewModel)
    case faq
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

struct HomeView: View {
    
    init(userManager: UserSessionManager) {
        self.userManager = userManager
    }
    
    @ObservedObject private var userManager: UserSessionManager
    
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var vm = ConcertsViewModel()
        
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(vm.visits) { visit in
                        Section(visit.title ?? visit.artist.name) {
                            visitSection(visit: visit)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                createButton
            }
            .onChange(of: navigationManager.path) { oldValue, newValue in
                if oldValue != newValue, newValue.isEmpty {
                    vm.reloadData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationManager.push(view: .profile)
                    } label: {
                        Image(systemName: "person")
                    }
                }
            }
            .navigationTitle("Concerts")
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .createVisitArtist:
                    CreateConcertSelectArtistView()
                        .environmentObject(navigationManager)
                case .createVisit(let viewModel):
                    CreateConcertVisitView(viewModel: viewModel)
                        .environmentObject(navigationManager)
                case .profile:
                    ProfileView(viewModel: ProfileViewModel(userProvider: userManager))
                        .environmentObject(navigationManager)
                case .faq:
                    FAQView()
                }
            }
        }
    }
    
    func visitSection(visit: FullConcertVisit) -> some View {
        HStack {
            Group {
                AsyncImage(url: URL(string: visit.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        Color.gray
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Color.red
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100)
        
            VStack(alignment: .leading) {
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
            .padding(.horizontal)
            
            Spacer()
        }
        .background {
            Color.black
        }
        .cornerRadius(10)
        .frame(maxWidth: .infinity)

    }
    
    var createButton: some View {
        HStack {
            Spacer()
            Button {
                navigationManager.push(view: .createVisitArtist)
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.glassProminent)
        }
        .padding()
    }
    
    private func refreshVisits() async {
        do {
            let results = try await vm.loadData()
            await MainActor.run { vm.visits = results }
        } catch {
            print("could not refresh concerts: \(error)")
        }
    }
    
}

//#Preview {
//    HomeView()
//}

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
    
    func reloadData() {
        Task {
            visits = try await loadData()
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

