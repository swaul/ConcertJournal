//
//  OnboardingManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Photos
import AppTrackingTransparency
import SwiftUI
import Supabase

@MainActor
@Observable
class OnboardingManager {

    // MARK: - Properties

    var path: [NavigationRoute] = []

    var onboardingSteps: [NavigationRoute] = [
            .termsPage,
            .featurePage,
            .photoPermission,
            .trackingPermission,
            .notificationPermission,
            .completion
    ]

    var currentIndex: Int { path.count }
    
    var isLoadingVersions: Bool = false
    var termsVersion: Int = 1
    var privacyVersion: Int = 1

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    var hasCompletedOnboarding: Bool

    var photoLibraryStatus: PHAuthorizationStatus = .notDetermined {
        didSet {
            withAnimation {
                photoLibraryStatusNotDetermined = photoLibraryStatus == .notDetermined
            }
        }
    }
    var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined {
        didSet {
            withAnimation {
                trackingStatusNotDetermined = trackingStatus == .notDetermined
            }
        }
    }
    var notificationStatus: UNAuthorizationStatus = .notDetermined {
        didSet {
            withAnimation {
                notificationStatusNotDetermined = notificationStatus == .notDetermined
            }
        }
    }

    var photoLibraryStatusNotDetermined: Bool = true
    var trackingStatusNotDetermined: Bool = true
    var notificationStatusNotDetermined: Bool = true
    
    private let supabaseClient: SupabaseClientManagerProtocol

    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    // MARK: - Permission Methods

    func requestPhotoLibraryAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryStatus = status
        logInfo("Photo library permission: \(status.rawValue)", category: .auth)
    }

    func requestTrackingPermission() async {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        trackingStatus = status
        logInfo("Tracking permission: \(status.rawValue)", category: .auth)
    }

    func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard granted == true else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            logError("Error while asking for notifcation permissions", error: error)
        }
    }

    func checkPhotoLibraryStatus() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if photoLibraryStatus != .notDetermined {
            onboardingSteps.removeAll(where: { $0 == .photoPermission })
        }
    }

    func checkTrackingStatus() {
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus

        if trackingStatus != .notDetermined {
            onboardingSteps.removeAll(where: { $0 == .trackingPermission })
        }
    }

    func getNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus

        if notificationStatus != .notDetermined {
            onboardingSteps.removeAll(where: { $0 == .notificationPermission })
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        hasCompletedOnboarding = true
        logSuccess("Onboarding completed", category: .auth)
    }
    
    func loadTermsVersions() async {
        isLoadingVersions = true
        
        do {
            // Hole Metadata von Supabase
            let response = try await supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: response.data)
            
            await MainActor.run {
                self.termsVersion = metadata.termsVersion
                self.privacyVersion = metadata.privacyVersion
                self.isLoadingVersions = false
            }
            
            print("✅ Loaded terms v\(metadata.termsVersion) & privacy v\(metadata.privacyVersion)")
        } catch {
            print("❌ Error loading terms versions: \(error)")
            isLoadingVersions = false
            // Fallback auf defaults (1, 1)
        }
    }
    
    func saveTermsConsent() {
        
        let isoString = ISO8601DateFormatter().string(from: Date())
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"

        let data = AcceptanceData(
            terms_accepted: true,
            terms_accepted_at: isoString,
            terms_version: termsVersion,
            privacy_accepted: true,
            privacy_accepted_at: isoString,
            privacy_version: privacyVersion,
            app_version: version
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: "compliance_acceptance")
            getNextStep()
        } catch {
            logError("Failed to encode acceptance data", error: error)
        }
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        hasCompletedOnboarding = false
    }

    func getNextStep() {
        let nextIndex = path.count  // wieviele Steps sind schon im path
        guard nextIndex < onboardingSteps.count else {
            completeOnboarding()
            return
        }
        path.append(onboardingSteps[nextIndex])
    }
}

struct AcceptanceData: Codable {
    let terms_accepted: Bool
    let terms_accepted_at: String
    let terms_version: Int
    
    let privacy_accepted: Bool
    let privacy_accepted_at: String
    let privacy_version: Int
    
    let app_version: String
}
