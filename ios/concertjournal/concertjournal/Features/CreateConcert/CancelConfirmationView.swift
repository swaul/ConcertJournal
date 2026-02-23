//
//  CancelConfirmationView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.02.26.
//

import SwiftUI

// MARK: - Cancel Confirmation Sheet

struct CancelConcertConfirmationView: View {

    var onDiscard: () -> Void
    var onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "music.mic.circle")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(Color.red)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Title
            Text("Konzert verwerfen?")
                .font(.custom("PlayfairDisplay-Bold", size: 22))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            // Subtitle
            Text("Deine Eingaben gehen verloren,\nwenn du jetzt abbrichst.")
                .font(.cjBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            // Buttons
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    onDiscard()
                } label: {
                    Text("Verwerfen")
                        .font(.cjTitle2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)

                Button {
                    onContinue()
                } label: {
                    Text("Weiter bearbeiten")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.05)) {
                appeared = true
            }
        }
    }
}
