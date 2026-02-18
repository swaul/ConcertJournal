//
//  concertjournalApp.swift
//  concertjournal
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
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance

        AdMobManager.shared.initialize()
    }

    @State private var navigationManager = NavigationManager()

    var body: some Scene {
        WindowGroup {
            let dependencyContainer = DependencyContainer()

            RootView(navigationManager: navigationManager)
                .preferredColorScheme(.dark)
                .withDependencies(dependencyContainer)
        }
    }
}

// MARK: - Helpers

struct PasswordResetRequest: Identifiable {
    var id: String { code + type }
    let code: String
    let type: String
}

// MARK: - Root View
// Einzige Entscheidung: Onboarding abgeschlossen? → App. Fertig.
// Login ist optional und wird vom Profil aus gesteuert.

struct RootView: View {

    @Environment(\.dependencies) var dependencies

    @State private var onboardingManager = OnboardingManager()
    @State var navigationManager: NavigationManager

    @State private var passwordResetItem: PasswordResetRequest? = nil
    @State private var importConcertItem: ExtractedConcertInfo? = nil

    var body: some View {
        Group {
            if !onboardingManager.hasCompletedOnboarding {
                OnboardingView(manager: onboardingManager)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                MainAppView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .withNavigationManager(navigationManager)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingManager.hasCompletedOnboarding)
        .onOpenURL { url in
            logInfo("Received URL: \(url.absoluteString)", category: .auth)
            guard url.scheme == "concertjournal" else { return }

            if url.host == "auth-callback" {
                Task {
                    do {
                        try await dependencies.supabaseClient.handleAuthCallback(from: url)
                        logSuccess("Auth callback processed", category: .auth)
                    } catch {
                        logError("Auth callback failed", error: error, category: .auth)
                    }
                }
            } else if url.host == "reset-password" || url.path.contains("reset-password") {
                handlePasswordReset(url: url)
            } else if url.host == "import-concert" {
                handleConcertImport()
            }
        }
        .task {
            // Session wiederherstellen – falls der User bereits eingeloggt war
            try? await dependencies.userSessionManager.start()
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
    }

    private func handlePasswordReset(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              let type = components?.queryItems?.first(where: { $0.name == "type" })?.value
        else { return }
        passwordResetItem = PasswordResetRequest(code: code, type: type)
    }

    private func handleConcertImport() {
        guard dependencies.userSessionManager.session != nil else { return }
        guard let sharedContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.de.kuehnel.concertjournal"
        ) else { return }

        let fileURL = sharedContainer.appendingPathComponent("pending_import.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        if let data = try? Data(contentsOf: fileURL),
           let concert = try? JSONDecoder().decode(ExtractedConcertInfo.self, from: data) {
            importConcertItem = concert
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
