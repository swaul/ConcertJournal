//
//  TermsUpdatedView.swift
//  concertjournal
//
//  Created by Paul Arbetit on 12.03.26.
//

import SwiftUI
import Supabase

struct TermsUpdatedView: View {
    
    struct UpdatedTerms: Identifiable {
        let id = UUID()
        let termsVersion: Int
        let privacyVersion: Int
    }
    
    @Environment(\.dependencies) private var dependencies
    
    @State private var termsAccepted = false
    @State private var privacyAccepted = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    
    let item: UpdatedTerms
    
    var onAccept: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                Text(TextKey.termsUpdatedMessage.localized)
                    .font(.cjTitleF)
                
                Spacer()
                
                HStack {
                    Image(systemName: "arrow.down")
                    Text(TextKey.termsUpdatedView.localized)
                        .font(.cjBody)
                    
                    Spacer()
                    
                    Text(TextKey.termsUpdatedAccept.localized)
                        .font(.cjBody)
                    Image(systemName: "arrow.down")
                }
                
                HStack {
                    Button {
                        showPrivacySheet = true
                    } label: {
                        Text(TextKey.termsUpdatedPrivacy.localized)
                            .font(.cjBody)
                            .underline()
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $privacyAccepted)
                }
                
                HStack {
                    Button {
                        showTermsSheet = true
                    } label: {
                        Text(TextKey.termsUpdatedTerms.localized)
                            .font(.cjBody)
                            .underline()
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $termsAccepted)
                }
                
                Button {
                    HapticManager.shared.navigationTap()
                    handleAccept()
                } label: {
                    Text(TextKey.genericConfirm.localized)
                        .font(.cjHeadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding(.top)
                .disabled(termsAccepted == false || privacyAccepted == false)
            }
            .padding()
            .navigationTitle(TextKey.termsUpdatedTitle.localized)
            .sheet(isPresented: $showTermsSheet) {
                HTMLTermsView()
            }
            .sheet(isPresented: $showPrivacySheet) {
                HTMLPrivacyView()
            }
        }
    }
    
    private func handleAccept() {
        Task {
            UserDefaults.standard.saveTermsConsent(termsVersion: item.termsVersion,
                                                   privacyVersion: item.privacyVersion)
            
            let metadata: [String: AnyJSON] = [
                "agb_accepted": .bool(true),
                "agb_accepted_at": .string(ISO8601DateFormatter().string(from: Date())),
                "datenschutz_accepted": .bool(true),
                "datenschutz_accepted_at": .string(ISO8601DateFormatter().string(from: Date())),
            ]
            
            let userAttributes = UserAttributes(data: metadata)
            
            guard let _ = try? await dependencies.supabaseClient.client.auth.session else {
                onAccept()
                return
            }
            try await dependencies.supabaseClient.client.auth.update(user: userAttributes)
            onAccept()
        }
    }
}

