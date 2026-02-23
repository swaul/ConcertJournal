//
//  PhotoPermissionPage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import Photos

// MARK: - Photo Permission Page

struct PhotoPermissionPage: View {
    
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
                    
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                }
                
                // Title
                Text(TextKey.photoAccess.localized)
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                // Description
                Text(TextKey.photoHint.localized)
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Permission Status
                PermissionStatusView(status: manager.photoLibraryStatus)
                
                // Action Button
                if manager.photoLibraryStatus == .notDetermined {
                    Button {
                        HapticManager.shared.buttonTap()
                        Task {
                            withAnimation {
                                isRequesting = true
                            }
                            await manager.requestPhotoLibraryAccess()
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
                } else if manager.photoLibraryStatus == .denied || manager.photoLibraryStatus == .restricted {
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
                }
                
                VStack(spacing: 14) {
                    if manager.photoLibraryStatusNotDetermined {
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
                            Text(TextKey.nextStep.localized)
                                .frame(maxWidth: .infinity)
                                .font(.cjTitle2)
                        }
                        .buttonStyle(.glass)
                        .disabled(manager.photoLibraryStatus == .notDetermined)
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    PhotoPermissionPage(manager: OnboardingManager())
}
