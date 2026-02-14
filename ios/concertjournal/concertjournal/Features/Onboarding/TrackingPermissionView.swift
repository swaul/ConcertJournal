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
                    
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                }
                
                // Title
                Text("App verbessern")
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                // Description
                Text("Hilf uns, Concert Journal zu verbessern, indem du anonyme Nutzungsdaten teilst.")
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                // Privacy Note
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.accentColor)
                    
                    Text("Deine Privatsphäre ist uns wichtig. Alle Daten werden anonym verarbeitet.")
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
                                Text("Erlauben")
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
                        Text("Einstellungen öffnen")
                            .font(.cjTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 40)
                }
                
                VStack(spacing: 14) {
                    if manager.trackingStatusNotDetermined {
                        Button {
                            HapticManager.shared.navigationTap()
                            navigationManager.push(.completion)
                        } label: {
                            Text("Überspringen")
                                .font(.cjFootnote)
                                .underline()
                        }
                    } else {
                        Button {
                            HapticManager.shared.navigationTap()
                            navigationManager.push(.completion)
                        } label: {
                            Text("Nächster Schritt!")
                                .frame(maxWidth: .infinity)
                                .font(.cjTitle2)
                        }
                        .buttonStyle(.glass)
                        .disabled(manager.trackingStatus == .notDetermined)
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal)
            }
        }
    }
}

