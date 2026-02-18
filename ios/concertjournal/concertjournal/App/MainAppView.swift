//
//  MainAppView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

struct MainAppView: View {

    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

#if DEBUG
    @State private var showDebugLogs = false
#endif

    var body: some View {
        @Bindable var navigationManager = navigationManager

        TabView(selection: $navigationManager.selectedTab) {
            Tab("Konzerte", systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView()
            }

            Tab("Karte", systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }

            Tab(value: NavigationRoute.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: navigationManager.selectedTab) { oldValue, newValue in
            print(newValue)
        }
        .tint(dependencies.colorThemeManager.appTint)
#if DEBUG
        .sheet(isPresented: $showDebugLogs) {
            DebugLogView()
        }
        .onAppear {
            DebugShakeManager.shared.onShake = {
                showDebugLogs.toggle()
            }
        }
#endif
    }
}
