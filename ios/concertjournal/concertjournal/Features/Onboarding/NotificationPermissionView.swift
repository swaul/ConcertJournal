//
//  NotificationPermissionView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.02.26.
//

import SwiftUI
import AppTrackingTransparency

// MARK: - Tracking Permission Page

struct NotificationPermissionView: View {

    @Bindable var manager: OnboardingManager

    @State private var isRequesting = false

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "app.badge")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                }

                // Title
                Text("Benachrichtigungen")
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)

                // Description
                Text("Erhalte Benachrichtigungen, wenn andere Nutzer sich als freund hinzufügen, oder in einem Konzert markieren.")
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)

                Spacer()

                // Permission Status
                NotificationStatusView(status: manager.notificationStatus)

                // Action Button
                if manager.notificationStatus == .notDetermined {
                    Button {
                        HapticManager.shared.buttonTap()
                        Task {
                            withAnimation {
                                isRequesting = true
                            }
                            await manager.requestNotificationPermission()
                            withAnimation {
                                isRequesting = false
                            }
                        }
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                                    .font(.cjTitle2)
                                Text(TextKey.queryRunning.localized)
                                    .font(.cjTitle2)
                            } else {
                                Text(TextKey.allow.localized)
                                    .font(.cjTitle2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isRequesting)
                    .padding(.horizontal, 40)
                } else if manager.notificationStatus == .denied {
                    Button {
                        HapticManager.shared.navigationTap()
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(TextKey.openSettings.localized)
                            .font(.cjTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 40)
                }

                VStack(spacing: 14) {
                    if manager.notificationStatusNotDetermined {
                        Button {
                            HapticManager.shared.navigationTap()
                            manager.getNextStep()
                        } label: {
                            Text(TextKey.skip.localized)
                                .font(.cjFootnote)
                                .underline()
                        }
                    } else {
                        Button {
                            HapticManager.shared.navigationTap()
                            manager.getNextStep()
                        } label: {
                            Text(TextKey.nextStepExclamation.localized)
                                .frame(maxWidth: .infinity)
                                .font(.cjTitle2)
                        }
                        .buttonStyle(.glass)
                        .disabled(manager.notificationStatus == .notDetermined)
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    NotificationPermissionView(manager: OnboardingManager())
}
