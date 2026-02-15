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

        AdMobManager.shared.initialize()
    }
    
    // MARK: - Dependency Container (erstellt alle Dependencies)

    @State private var dependencies = DependencyContainer()
    @State private var onboardingManager = OnboardingManager()
    @State private var navigationManager = NavigationManager()

    @State private var hasCompletedOnboarding = false

    // MARK: - App State

    @State private var passwordResetItem: PasswordResetRequest? = nil
    @State private var importConcertItem: ExtractedConcertInfo? = nil

    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LoadingView()
                } else if !hasCompletedOnboarding {
                    OnboardingView(manager: onboardingManager)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    if dependencies.userSessionManager.user != nil {
                        MainAppView()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .withNavigationManager(navigationManager)
                    } else {
                        LoginView(manager: onboardingManager, viewModel: AuthViewModel(supabaseClient: dependencies.supabaseClient, userSessionManager: dependencies.userSessionManager))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(dependencies.colorThemeManager.appTint)
            .environment(\.appTintColor, dependencies.colorThemeManager.appTint)
            .withDependencies(dependencies)
            .onChange(of: onboardingManager.hasCompletedOnboarding) { _, newValue in
                withAnimation {
                    hasCompletedOnboarding = newValue
                }
            }
            .sheet(item: $passwordResetItem) { item in
                PasswordResetView(passwordResetRequest: item)
            }
            .sheet(item: $importConcertItem) { item in
                ConcertImportView(extractedInfo: item) { importedConcert in
                    importConcertItem = nil
                    navigationManager.push(NavigationRoute.createConcertFromImport(importedConcert))
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

                guard url.scheme == "concertjournal" else { return }
                // Check if this is an auth callback
                if url.host == "auth-callback" {
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
                } else if url.host == "reset-password" || url.path.contains("reset-password") {
                    logInfo("Received password reset deeplink", category: .auth)
                    handlePasswordReset(url: url)
                } else if url.host == "import-concert" {
                    handleConcertImport()
                }
            }
        }
    }

    func handlePasswordReset(url: URL) {
        // Extrahiere code und type aus URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              let type = components?.queryItems?.first(where: { $0.name == "type" })?.value else {
            return
        }

        self.passwordResetItem = PasswordResetRequest(code: code, type: type)
    }

    func handleConcertImport() {
        guard dependencies.userSessionManager.session != nil else {
            logWarning("Tried to import concert, but not logged in", category: .import)
            return
        }
        // Lade Konzert aus shared container
        guard let sharedContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.de.kuehnel.concertjournal"
        ) else {
            logWarning("Tried to import concert, but no shared Container was found", category: .import)
            return
        }

        let fileURL = sharedContainer.appendingPathComponent("pending_import.json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logWarning("Tried to import concert, file was not found", category: .import)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let concert = try JSONDecoder().decode(ExtractedConcertInfo.self, from: data)

            // Zeige Import-Screen
            importConcertItem = concert

            // Lösche Datei
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to import concert: \(error)")
        }
    }
}

struct PasswordResetRequest: Identifiable {
    var id: String {
        code + type
    }

    let code: String
    let type: String
}
