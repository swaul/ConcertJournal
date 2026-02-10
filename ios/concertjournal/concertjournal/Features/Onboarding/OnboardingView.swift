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

    var manager: OnboardingManager

    @State var navigationManager = NavigationManager()

    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            WelcomePage(navigationManager: navigationManager)
                .navigationDestination(for: NavigationRoute.self) { route in
                    navigationDestination(for: route)
                }
        }
        .onAppear {
            manager.checkPhotoLibraryStatus()
            manager.checkTrackingStatus()
        }
    }

    @ViewBuilder
    private func navigationDestination(for route: NavigationRoute) -> some View {
        switch route {
        case .featurePage:
            FeaturesPage(navigationManager: navigationManager)
        case .photoPermission:
            PhotoPermissionPage(navigationManager: navigationManager, manager: manager)
        case .trackingPermission:
            TrackingPermissionPage(navigationManager: navigationManager, manager: manager)
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
