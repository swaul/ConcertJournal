//
//  concertjournalApp.swift
//  concertjournal
//

import SwiftUI
import Combine

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var pushManager: PushNotificationManagerProtocol?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await pushManager?.storeDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logError("Push registration failed", error: error, category: .auth)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "buddy_request", "buddy_accepted":
            let requestId = userInfo["request_id"] as? String
            NotificationCenter.default.post(name: .openBuddies, object: requestId)
        case "concert_tagged":
            if let concertId = userInfo["concert_id"] as? String {
                NotificationCenter.default.post(name: .openConcert, object: concertId)
            }
        default:
            break
        }
    }
}

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

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var navigationManager = NavigationManager()
    @State private var dependencyContainer = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            RootView(localizationManager: LocalizationManager(supabaseClient: dependencyContainer.supabaseClient), navigationManager: navigationManager)
                .preferredColorScheme(.dark)
                .withDependencies(dependencyContainer)
                .task {
                    appDelegate.pushManager = dependencyContainer.pushNotificationManager
                }
        }
    }
}

// MARK: - Helpers

struct PasswordResetRequest: Identifiable {
    var id: String { code + type }
    let code: String
    let type: String
}

struct BuddyCode: Identifiable {
    var id: String {
        code
    }
    
    let code: String
}

// MARK: - Root View

struct RootView: View {

    @Environment(\.dependencies) var dependencies

    @State var localizationManager: LocalizationManager

    @State private var onboardingManager = OnboardingManager()
    @State var navigationManager: NavigationManager

    @State private var passwordResetItem: PasswordResetRequest? = nil
    @State private var importConcertItem: ExtractedConcertInfo? = nil
    
    @State private var showBuddySheetWithCode: BuddyCode? = nil
    
    @State private var loadingLocalization: Bool = true

    var body: some View {
        Group {
            if loadingLocalization {
                TextLessLoadingView()
            } else if !onboardingManager.hasCompletedOnboarding {
                OnboardingView(manager: onboardingManager)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                MainAppView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .withNavigationManager(navigationManager)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingManager.hasCompletedOnboarding)
        .task {
            loadingLocalization = true
            await localizationManager.checkAndUpdateLocalizationIfNeeded()
            TextManager.shared.configure(with: localizationManager)
            loadingLocalization = false
        }
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
            } else if url.host == "buddy", let code = url.pathComponents.last {
                dependencies.appState.pendingBuddyCode = code
                showBuddySheetWithCode = BuddyCode(code: code)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBuddies)) { notification in
            navigationManager.selectedTab = .buddies
        }
        .onReceive(NotificationCenter.default.publisher(for: .openConcert)) { notification in
            if let concertId = notification.object as? String {
                navigationManager.selectedTab = .concerts
                navigationManager.push(.concertDetailAsync(concertId))
            }
        }
        .task {
            try? await dependencies.userSessionManager.start()
        }
        .sheet(item: $showBuddySheetWithCode) { item in
            BuddyQuickAddSheet(code: item)
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
            forSecurityApplicationGroupIdentifier: "group.com.kuehnel.concertjournal"
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
