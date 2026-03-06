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
                            try? await Task.sleep(for: .seconds(2))
                            manager.getNextStep()
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
                                Text(TextKey.nextStepExclamation.localized)
                                    .font(.cjTitle2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isRequesting)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
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
                    
                    Button {
                        HapticManager.shared.buttonTap()
                        manager.getNextStep()
                    } label: {
                        Text("Das passt so")
                            .font(.cjFootnote)
                            .underline()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isRequesting)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
