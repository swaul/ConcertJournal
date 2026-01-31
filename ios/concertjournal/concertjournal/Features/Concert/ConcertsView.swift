//
//  ConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.12.25.
//

import SwiftUI

struct ConcertsView: View {
    @Environment(\.dependencies) private var dependencies
    
    @State private var navigationManager = NavigationManager()

    @State private var viewModel: ConcertsViewModel? = nil

    @State private var searchText: String = ""
        
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            Group {
                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .task {
                if viewModel == nil {
                    guard let userId = dependencies.supabaseClient.currentUserId?.uuidString else {
                        return
                    }

                    // ViewModel wird mit Dependencies aus Container erstellt
                    viewModel = ConcertsViewModel(
                        concertRepository: dependencies.concertRepository,
                        userId: userId
                    )

                    // Daten laden
                    await viewModel?.loadConcerts()
                }
            }
            .navigationTitle("Concerts")
            .navigationDestination(for: NavigationRoute.self) { route in
                navigationDestination(for: route)
            }
        }
        .withNavigationManager(navigationManager)
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: ConcertsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !viewModel.futureConcerts.isEmpty {
                    Text("Deine nächsten Konzerte")
                        .font(.title)
                        .padding(.vertical)

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.futureConcerts) { visit in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(visit.date.dateOnlyString)
                                        .padding(2)
                                        .font(.caption)
                                        .glassEffect()
                                    Button {
                                        navigationManager.push(.concertDetail(visit))
                                    } label: {
                                        futureConcert(concert: visit)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }
                    }
                    .scrollTargetBehavior(.viewAligned(anchor: .leading))
                    .scrollClipDisabled()
                    .scrollIndicators(.hidden)

                    Text("Vergangene Konzerte")
                        .font(.title)
                        .padding(.vertical)
                }
                ForEach(viewModel.pastConcerts) { visit in
                    Section(visit.title ?? visit.artist.name) {
                        Button {
                            navigationManager.push(.concertDetail(visit))
                        } label: {
                            visitSection(visit: visit)
                        }
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            createButton(viewModel: viewModel)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigationManager.push(.profile)
                } label: {
                    Image(systemName: "person")
                }
            }
        }
    }

    @ViewBuilder
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
        .compositingGroup()
        .background {
            dependencies.colorThemeManager.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 100)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: UIColor.systemBackground))
                .shadow(radius: 3, x: 2, y: 2)
        }
    }

    @ViewBuilder
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
            dependencies.colorThemeManager.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(height: 100)
    }

    @ViewBuilder
    func createButton(viewModel: ConcertsViewModel) -> some View {
        HStack {
            Spacer()
            VStack {
                Button {
                    var allConcerts = viewModel.pastConcerts
                    allConcerts.append(contentsOf: viewModel.futureConcerts)
                    navigationManager.push(.map(allConcerts))
                } label: {
                    Image(systemName: "map")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .padding(8)
                }
                .buttonStyle(.glass)
                Button {
                    navigationManager.push(.createConcert)
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

    @ViewBuilder
    private func navigationDestination(for route: NavigationRoute) -> some View {
        switch route {
        case .concertDetail(let concert):
            ConcertDetailView(concert: concert)

        case .createSetlist:
            CreateSetlistView()

        case .colorPicker:
            ColorSetView()

        case .faq:
            FAQView()

        case .profile:
            ProfileView()

        default:
            Text("Not implemented: \(String(describing: route))")
        }
    }


    private func refreshVisits() async {
        await viewModel?.loadConcerts()
    }

}

#Preview {
    ConcertsView()
        .environmentObject(ColorThemeManager())
}
