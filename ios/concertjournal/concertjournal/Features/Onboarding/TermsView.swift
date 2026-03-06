//
//  TermsPage.swift
//  concertjournal
//
//  Created by Paul Arbetit on 05.03.26.
//

import SwiftUI
import Supabase

struct TermsView: View {
    @Environment(\.dependencies) var dependencies

    @State private var termsAccepted = false
    @State private var privacyAccepted = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    
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
                Text("Erstmal das rechtliche..")
                    .font(.custom("PlayfairDisplay-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                // Description
                Text("Bitte ließ dir die AGB und Datenschutzbestimmungen durch und akzeptiere sie.")
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                HStack {
                    Image(systemName: "arrow.down")
                    Text("Lesen")
                    
                    Spacer()
                    
                    Text("Akzeptieren")
                    Image(systemName: "arrow.down")
                }
                .padding(.horizontal, 40)
                .font(.caption)
                .opacity(0.7)
                
                HStack {
                    Button {
                        showPrivacySheet = true
                    } label: {
                        Text("Datenschutz")
                            .font(.cjBody)
                            .underline()
                    }
                    Text("v\(manager.privacyVersion)")
                        .font(.caption2)
                        .opacity(0.6)
                    
                    Spacer()
                    
                    Toggle("", isOn: $privacyAccepted)
                }
                .padding(.horizontal, 40)

                HStack {
                    Button {
                        showTermsSheet = true
                    } label: {
                        Text("AGB")
                            .font(.cjBody)
                            .underline()
                    }
                    Text("v\(manager.termsVersion)")
                        .font(.caption2)
                        .opacity(0.6)
                    
                    Spacer()
                    
                    Toggle("", isOn: $privacyAccepted)
                }
                .padding(.horizontal, 40)

                Button {
                    HapticManager.shared.navigationTap()
                    manager.getNextStep()
                } label: {
                    if manager.isLoadingVersions {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(TextKey.nextStepExclamation.localized)
                            .font(.cjTitle2)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(termsAccepted == false || privacyAccepted == false || manager.isLoadingVersions)
            }
        }
        .task {
            await manager.loadTermsVersions()
        }
        .sheet(isPresented: $showPrivacySheet) {
            HTMLPrivacyView()
        }
        .sheet(isPresented: $showTermsSheet) {
            HTMLTermsView()
        }
    }
}
