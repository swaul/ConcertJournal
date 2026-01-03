//
//  ConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.12.25.
//

import SwiftUI

struct ConcertsView: View {
    @EnvironmentObject var colorTheme: ColorThemeManager

    init(userManager: UserSessionManager) {
        self.userManager = userManager
    }
    
    @ObservedObject private var userManager: UserSessionManager
    
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var vm = ConcertsViewModel()
    
    @State private var searchText: String = ""
        
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            ScrollView {
                VStack(alignment: .leading) {
                    if !vm.futureVisits.isEmpty {
                        Text("FUTURE CONCERTS")
                            .padding()
                            .glassEffect()
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 16) {
                                ForEach(vm.futureVisits) { visit in
                                    Button {
                                        navigationManager.push(view: .concertDetail(visit))
                                    } label: {
                                        futureConcert(concert: visit)
                                    }
                                    .scrollTargetLayout()
                                }
                            }
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollClipDisabled()
                        .scrollIndicators(.hidden)
                    }
                    Text("PAST CONCERTS")
                        .padding()
                        .glassEffect()
                    ForEach(vm.visits) { visit in
                        Section(visit.title ?? visit.artist.name) {
                            Button {
                                navigationManager.push(view: .concertDetail(visit))
                            } label: {
                                visitSection(visit: visit)
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                createButton
            }
            .searchable(text: $searchText, placement: .toolbar)
            .tabBarMinimizeBehavior(.onScrollDown)
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
                case .createVisit:
                    CreateConcertVisitView()
                        .environmentObject(navigationManager)
                case .profile:
                    ProfileView(viewModel: ProfileViewModel(userProvider: userManager))
                        .environmentObject(navigationManager)
                case .faq:
                    FAQView()
                case .colorPicker:
                    ColorSetView()
                        .environmentObject(colorTheme)
                case .concertDetail(let concert):
                    ConcertDetailView(concert: concert)
                        .environmentObject(colorTheme)
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
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.red
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100, height: 100)
        
            VStack(alignment: .leading) {
                Text(visit.artist.name)
                    .lineLimit(nil)
                    .font(.title2)
                    .foregroundStyle(.white)
                if let venue = visit.venue {
                    Text(venue.name)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let city = visit.city {
                    Text(city)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background {
            colorTheme.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 100)
    }
    
    func futureConcert(concert: FullConcertVisit) -> some View {
        HStack {
            Group {
                AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        Color.gray
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.red
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100, height: 100)
        
            VStack(alignment: .leading) {
                Text(concert.artist.name)
                    .lineLimit(nil)
                    .font(.title2)
                    .foregroundStyle(.white)
                if let venue = concert.venue {
                    Text(venue.name)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let city = concert.city {
                    Text(city)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background {
            colorTheme.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(height: 100)
    }
    
    var createButton: some View {
        HStack {
            Spacer()
            VStack {
                Button {
                    print("Show map")
                } label: {
                    Image(systemName: "map")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .padding(8)
                }
                .buttonStyle(.glass)
                Button {
                    navigationManager.push(view: .createVisit)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .padding(8)
                }
                .buttonStyle(.glassProminent)
            }
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


#Preview {
    ConcertsView(userManager: UserSessionManager())
        .environmentObject(ColorThemeManager())
}
