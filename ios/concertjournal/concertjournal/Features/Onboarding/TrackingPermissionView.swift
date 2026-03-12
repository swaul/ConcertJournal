//
//  Untitled.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import AppTrackingTransparency

// MARK: - Tracking Permission Page

struct TrackingPermissionPage: View {

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
                    
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                }
                
                // Title
                Text(TextKey.improveApp.localized)
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                // Description
                Text(TextKey.analyticsHint.localized)
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                // Privacy Note
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.accentColor)
                    
                    Text(TextKey.privacyHint.localized)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .font(.cjFootnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Permission Status
                TrackingStatusView(status: manager.trackingStatus)
                
                // Action Button
                if manager.trackingStatus == .notDetermined {
                    Button {
                        HapticManager.shared.buttonTap()
                        Task {
                            withAnimation {
                                isRequesting = true
                            }
                            await manager.requestTrackingPermission()
                            withAnimation {
                                isRequesting = false
                            }
                            
                            try? await Task.sleep(for: .seconds(2))
                            manager.getNextStep()
                        }
                    } label: {
                        HStack {
                            if isRequesting {
                                    FlowerLoading()
                                    .frame(width: 40, height: 40)
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
                } else if manager.trackingStatus == .denied || manager.trackingStatus == .restricted {
                    Button {
                        HapticManager.shared.navigationTap()
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(TextKey.openSettings.localized)
                            .font(.cjHeadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.glassProminent)
                    
                    Button {
                        HapticManager.shared.navigationTap()
                        manager.getNextStep()
                    } label: {
                        Text("Das passt so")
                            .font(.cjFootnote)
                            .padding()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}
