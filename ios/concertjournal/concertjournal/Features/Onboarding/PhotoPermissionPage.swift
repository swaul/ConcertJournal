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
    
    @Bindable var navigationManager: NavigationManager
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
                Text("Zugriff auf Fotos")
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                // Description
                Text("Füge Fotos zu deinen Konzerten hinzu und erstelle unvergessliche Erinnerungen.")
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
                                Text("Abfrage läuft...")
                                    .font(.cjTitle2)
                            } else {
                                Text("Zugriff erlauben")
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
                        Text("Einstellungen öffnen")
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
                            navigationManager.push(.trackingPermission)
                        } label: {
                            Text("Überspringen")
                                .font(.cjFootnote)
                                .underline()
                        }
                    } else {
                        Button {
                            HapticManager.shared.navigationTap()
                            navigationManager.push(.trackingPermission)
                        } label: {
                            Text("Nächster Schritt")
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
