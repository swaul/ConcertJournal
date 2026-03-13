//
//  WelcomePage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

// MARK: - Welcome Page

struct WelcomePage: View {
    
    @Bindable var manager: OnboardingManager

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
                
                // App Icon/Logo
                Image(systemName: "music.note.list")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 20)
                
                // Title
                Text(TextKey.onboardingWelcomeTitle.localized)
                    .font(.cjTitle2)
                    .foregroundColor(.secondary)
                
                Text(TextKey.onboardingWelcomeAppName.localized)
                    .font(.cjLargeTitle)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(TextKey.onboardingWelcomeTagline.localized)
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
                
                Button {
                    manager.getNextStep()
                } label: {
                    Text(TextKey.onboardingWelcomeLetsGo.localized)
                        .frame(maxWidth: .infinity)
                        .font(.cjTitle2)
                }
                .buttonStyle(.glass)
                .padding(.bottom, 30)
            }
            .padding()
        }
    }
}
