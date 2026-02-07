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
                        LoginView(viewModel: AuthViewModel(supabaseClient: dependencies.supabaseClient, userSessionManager: dependencies.userSessionManager))
                    }
                }
            }
            .tint(dependencies.colorThemeManager.appTint)
            .environment(\.appTintColor, dependencies.colorThemeManager.appTint)
            .withDependencies(dependencies)
            .task {
                do {
                    try await dependencies.userSessionManager.start()
                } catch {
                    print(error)
                }
            }
            .task {
                await dependencies.localizationRepository.loadLocale("de")
                isLoading = false
            }
            .onOpenURL { url in
                logInfo("Received URL: \(url.absoluteString)", category: .auth)
                
                // Check if this is an auth callback
                if url.scheme == "concertjournal" && url.host == "auth-callback" {
                    logInfo("Processing auth callback", category: .auth)
                    
                    Task {
                        do {
                            // ✅ Supabase verarbeitet den Callback
                            try await dependencies.supabaseClient.handleAuthCallback(from: url)
                            
                            logSuccess("Auth callback processed successfully", category: .auth)
                            
                            // Refresh user session
                            try await dependencies.userSessionManager.start()
                            
                        } catch {
                            logError("Failed to process auth callback", error: error, category: .auth)
                        }
                    }
                }
            }
        }
    }
}
