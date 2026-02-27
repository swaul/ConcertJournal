//
//  OnboardingManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Photos
import AppTrackingTransparency
import SwiftUI

@MainActor
@Observable
class OnboardingManager {

    // MARK: - Properties

    var path: [NavigationRoute] = []

    var onboardingSteps: [NavigationRoute] = [
            .featurePage,
            .photoPermission,
            .trackingPermission,
            .notificationPermission,
            .completion
    ]

    var currentIndex: Int { path.count }

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

    init() {
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
