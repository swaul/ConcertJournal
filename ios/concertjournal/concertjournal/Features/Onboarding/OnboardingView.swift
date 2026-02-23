//
//  OnboardingView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {

    @Environment(\.dismiss) var dismiss

    @State var manager: OnboardingManager

    var body: some View {
        NavigationStack(path: $manager.path) {
            WelcomePage(manager: manager)
                .navigationDestination(for: NavigationRoute.self) { route in
                    navigationDestination(for: route)
                }
        }
        .task {
            manager.checkPhotoLibraryStatus()
            manager.checkTrackingStatus()
            await manager.getNotificationStatus()
        }
    }

    @ViewBuilder
    private func navigationDestination(for route: NavigationRoute) -> some View {
        switch route {
        case .featurePage:
            FeaturesPage(manager: manager)
        case .photoPermission:
            PhotoPermissionPage(manager: manager)
        case .trackingPermission:
            TrackingPermissionPage(manager: manager)
        case .notificationPermission:
            NotificationPermissionView(manager: manager)
        case .completion:
            CompletionPage(manager: manager)
        default:
            Text("Not implemented: \(String(describing: route))")
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(manager: OnboardingManager())
}
