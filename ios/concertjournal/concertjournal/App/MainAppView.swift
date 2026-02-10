//
//  MainAppView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

struct MainAppView: View {

    @Environment(\.dependencies) private var dependencies

    @State private var navigationManager = NavigationManager()

    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            Tab("Konzerte", systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView()
            }

            Tab("Karte", systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }

            Tab(value: NavigationRoute.search, role: .search) {
                SearchView(viewModel: SearchViewModel(concertRepository: dependencies.concertRepository))
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
