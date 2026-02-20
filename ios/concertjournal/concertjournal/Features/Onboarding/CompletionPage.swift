//
//  CompletionPage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

// MARK: - Completion Page

struct CompletionPage: View {

    @Bindable var manager: OnboardingManager

    @State var width: CGFloat = 100

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
                
                // Success Icon
                ZStack {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .blur(radius: 5)
                            .frame(width: width, height: width)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                                    width = 140
                                }
                            }
                    }
                    .frame(height: 140)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }

                // Title
                Text(TextKey.confirmReady.localized)
                    .font(.custom("PlayfairDisplay-Bold", size: 36))
                
                // Description
                Text(TextKey.onboardingReady.localized)
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Get Started Button
                Button(action: { manager.completeOnboarding() }) {
                    HStack {
                        Text(TextKey.letsGo.localized)
                            .font(.cjTitle2)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            
        }
    }
}

#Preview {
    CompletionPage(manager: OnboardingManager())
}
