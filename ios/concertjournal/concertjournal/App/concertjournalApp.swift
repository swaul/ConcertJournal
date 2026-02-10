//
//  concertjournalApp.swift
//  concertjournal
//
//  Refactored App Entry Point mit Dependency Injection
//

import SwiftUI
import Combine

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
    @State private var onboardingManager = OnboardingManager()

    @State private var hasCompletedOnboarding = false

    // MARK: - App State

    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(2.5)
                } else if !hasCompletedOnboarding {
                    OnboardingView(manager: onboardingManager)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    if dependencies.userSessionManager.user != nil {
                        MainAppView()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        LoginView(manager: onboardingManager, viewModel: AuthViewModel(supabaseClient: dependencies.supabaseClient, userSessionManager: dependencies.userSessionManager))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .tint(dependencies.colorThemeManager.appTint)
            .environment(\.appTintColor, dependencies.colorThemeManager.appTint)
            .withDependencies(dependencies)
            .onChange(of: onboardingManager.hasCompletedOnboarding) { _, newValue in
                withAnimation {
                    hasCompletedOnboarding = newValue
                }
            }
            .task {
                hasCompletedOnboarding = onboardingManager.hasCompletedOnboarding
                logInfo("App starting user session", category: .auth)
                do {
                    try await dependencies.userSessionManager.start()
                    logInfo("User session started successfully", category: .auth)
                } catch {
                    logError("Failed to start user session", error: error, category: .auth)
                }
            }
            .task {
                await dependencies.localizationRepository.loadLocale("de")
            }
            .onReceive(dependencies.userSessionManager.userSessionChanged) { _ in
                if isLoading {
                    withAnimation {
                        isLoading = false
                    }
                }
                dependencies.concertRepository.reset()
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
                            
                            // Removed: try await dependencies.userSessionManager.start()
                            // Rely on auth state stream to update session
                            
                        } catch {
                            logError("Failed to process auth callback", error: error, category: .auth)
                        }
                    }
                }
            }
        }
    }
}
