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
    @State private var showICloudWarning = false
    @State private var showDecryptionProblem = false
    
    var body: some View {
        @Bindable var navigationManager = navigationManager
        @Bindable var dependencyContainer = dependencies

        TabView(selection: $navigationManager.selectedTab) {
            Tab(TextKey.concerts.localized, systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView()
            }

            Tab(TextKey.map.localized, systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }
            
            Tab(TextKey.buddies.localized, systemImage: "person.2.fill", value: NavigationRoute.buddies) {
                BuddiesView()
            }

            Tab(value: NavigationRoute.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
            print(TextKey.name.localized)
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudKeychainUnavailable)) { _ in
            showICloudWarning = true
        }
        .alert(TextKey.icloudWarning.localized, isPresented: $showICloudWarning) {
            Button(TextKey.understood.localized) {}
            Button(TextKey.openSettings.localized) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        } message: {
            Text("iCloud ist auf diesem Gerät nicht aktiv. Deine Daten werden verschlüsselt, aber der Schlüssel kann nicht zwischen deinen Geräten synchronisiert werden. Aktiviere iCloud unter Einstellungen für vollen Schutz.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncingProblem)) { _ in
            showDecryptionProblem = true
        }
        .alert(TextKey.decryptionFailed.localized, isPresented: $showDecryptionProblem) {
            Button(TextKey.understood.localized) {}
        } message: {
            Text(TextKey.decryptionDesc.localized)
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
