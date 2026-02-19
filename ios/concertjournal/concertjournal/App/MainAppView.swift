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

    @State private var showSetup = false

    var body: some View {
        @Bindable var navigationManager = navigationManager
        @Bindable var dependencyContainer = dependencies

        TabView(selection: $navigationManager.selectedTab) {
            Tab("Konzerte", systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView()
            }

            Tab("Karte", systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }
            
            Tab("Buddies", systemImage: "person.2.fill", value: NavigationRoute.buddies) {
                BuddiesView()
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
        .fullScreenCover(isPresented: $showSetup) {
            UserSetupView {
                showSetup = false
            }
        }
        .onChange(of: dependencyContainer.needsSetup) { _, needsSetup in
            showSetup = needsSetup
        }
        .onAppear {
            showSetup = dependencies.needsSetup
        }
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
