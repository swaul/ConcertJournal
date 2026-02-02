//
//  concertjournalApp.swift
//  concertjournal
//
//  Refactored App Entry Point mit Dependency Injection
//

import SwiftUI

@main
struct ConcertJournalApp: App {

    init() {
        let appearance = UINavigationBarAppearance()

        appearance.titleTextAttributes = [
            .font: UIFont(name: "Manrope-SemiBold", size: 18)!
        ]

        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Manrope-Bold", size: 34)!
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    // MARK: - Dependency Container (erstellt alle Dependencies)

    @State private var dependencies = DependencyContainer()

    // MARK: - App State

    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(2.5)
                } else {
                    if dependencies.userSessionManager.user != nil {
                        ConcertsView()
                    } else {
                        LoginView()
                    }
                }
            }
            .tint(dependencies.colorThemeManager.appTint)
            .environment(\.appTintColor, dependencies.colorThemeManager.appTint)

            // Dependency Injection via Environment
            .withDependencies(dependencies)

            // Setup Tasks
            .task {
                await dependencies.userSessionManager.start()
            }
            .task {
                await dependencies.localizationRepository.loadLocale("de")
                isLoading = false
            }

            // Auth Callback Handler
            .onOpenURL { url in
                Task {
                    try? await dependencies.supabaseClient.handleAuthCallback(from: url)
                }
            }
        }
    }
}
