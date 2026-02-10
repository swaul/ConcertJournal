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

    var photoLibraryStatusNotDetermined: Bool = true
    var trackingStatusNotDetermined: Bool = true

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

    func checkPhotoLibraryStatus() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func checkTrackingStatus() {
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
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
}
