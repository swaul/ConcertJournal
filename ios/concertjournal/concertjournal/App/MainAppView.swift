//
//  MainAppView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import Supabase

struct MainAppView: View {

    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

#if DEBUG
    @State private var showDebugLogs = false
#endif

    @State private var showSetup = false
    @State private var showDecryptionProblem = false
    @State private var showTermsUpdated: TermsUpdatedView.UpdatedTerms? = nil
        
    var body: some View {
        @Bindable var navigationManager = navigationManager
        @Bindable var dependencyContainer = dependencies

        TabView(selection: $navigationManager.selectedTab) {
            Tab(TextKey.concerts.localized, systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView()
            }

            Tab(TextKey.map.localized, systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }
            
            Tab(TextKey.buddies.localized, systemImage: "person.2.fill", value: NavigationRoute.buddies) {
                BuddiesView()
            }

            Tab(value: NavigationRoute.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(dependencies.colorThemeManager.appTint)
        .task {
            await checkTermsUpdateRequired()
        }
        .fullScreenCover(isPresented: $showSetup) {
            UserSetupView {
                showSetup = false
            }
        }
        .onChange(of: dependencyContainer.needsSetup) { _, needsSetup in
            showSetup = needsSetup
        }
        .onAppear {
            showSetup = dependencies.needsSetup
            print(TextKey.name.localized)
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncingProblem)) { _ in
            showDecryptionProblem = true
        }
        .alert(TextKey.decryptionFailed.localized, isPresented: $showDecryptionProblem) {
            Button(TextKey.understood.localized) {}
        } message: {
            Text(TextKey.decryptionDesc.localized)
        }
        .sheet(item: $showTermsUpdated) { item in
            TermsUpdatedView(item: item) {
                showTermsUpdated = nil
            }
            .interactiveDismissDisabled()
        }
#if DEBUG
        .sheet(isPresented: $showDebugLogs) {
            DebugLogView()
        }
        .onAppear {
            DebugShakeManager.shared.onShake = {
                showDebugLogs.toggle()
            }
        }
#endif
    }
    
    func checkTermsUpdateRequired() async {
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }

        do {
            let response = try await dependencies.supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: response.data)
            
            let serverTermsVersion = metadata.termsVersion
            let serverPrivacyVersion = metadata.privacyVersion
            
            if UserDefaults.standard.isTermsUpdateRequired(
                currentTermsVersion: serverTermsVersion,
                currentPrivacyVersion: serverPrivacyVersion
            ) {
                showTermsUpdated = TermsUpdatedView.UpdatedTerms(termsVersion: serverTermsVersion,
                                                                 privacyVersion: serverPrivacyVersion)
            }
        } catch {
            print("Error checking terms update: \(error)")
        }
    }
}

// MARK: - Terms & Privacy Models

struct TermsConsent: Codable {
    let terms_accepted: Bool
    let terms_accepted_at: String
    let terms_version: Int
    
    let privacy_accepted: Bool
    let privacy_accepted_at: String
    let privacy_version: Int
    
    let app_version: String
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    
    private enum Keys {
        static let termsConsent = "com.concertjournal.terms_consent"
    }
    
    // MARK: - Save Terms Consent
    
    func saveTermsConsent(termsVersion: Int, privacyVersion: Int, hasAccount: Bool = false) {
        let isoString = ISO8601DateFormatter().string(from: Date())
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        let consent = TermsConsent(
            terms_accepted: true,
            terms_accepted_at: isoString,
            terms_version: termsVersion,
            
            privacy_accepted: true,
            privacy_accepted_at: isoString,
            privacy_version: privacyVersion,
            
            app_version: appVersion,
        )
        
        do {
            let encoded = try JSONEncoder().encode(consent)
            self.set(encoded, forKey: Keys.termsConsent)
            print("✅ Terms v\(termsVersion) & Privacy v\(privacyVersion) saved")
        } catch {
            print("❌ Failed to encode terms consent: \(error)")
        }
    }
    
    // MARK: - Get Terms Consent
    
    func getTermsConsent() -> TermsConsent? {
        guard let data = self.data(forKey: Keys.termsConsent) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(TermsConsent.self, from: data)
        } catch {
            print("❌ Failed to decode terms consent: \(error)")
            return nil
        }
    }
    
    // MARK: - Check if Terms Update Required
    
    func isTermsUpdateRequired(currentTermsVersion: Int, currentPrivacyVersion: Int) -> Bool {
        guard let consent = getTermsConsent() else {
            return true  // No consent saved yet
        }
        
        let termsUpdateNeeded = currentTermsVersion > consent.terms_version
        let privacyUpdateNeeded = currentPrivacyVersion > consent.privacy_version
        
        return termsUpdateNeeded || privacyUpdateNeeded
    }
    
    // MARK: - Debug Helper
    
    func debugTermsConsent() {
        if let consent = getTermsConsent() {
            print("""
            🔍 Terms Consent Status:
            - Terms v\(consent.terms_version) accepted at \(consent.terms_accepted_at)
            - Privacy v\(consent.privacy_version) accepted at \(consent.privacy_accepted_at)
            - App Version: \(consent.app_version)
            """)
        } else {
            print("❌ No terms consent found")
        }
    }
    
    // MARK: - Clear Terms Consent (for testing/debugging)
    
    func clearTermsConsent() {
        self.removeObject(forKey: Keys.termsConsent)
        print("🗑️ Terms consent cleared")
    }
}

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
                Text("Wir haben unsere Richtlinien geändert. Bitte überprüfe diese erneut.")
                    .font(.cjTitleF)
                
                Spacer()
                
                HStack {
                    Image(systemName: "arrow.down")
                    Text("Lesen")
                    
                    Spacer()
                    
                    Text("Akzeptieren")
                    Image(systemName: "arrow.down")
                }
                
                HStack {
                    Button {
                        showPrivacySheet = true
                    } label: {
                        Text("Datenschutz")
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
                        Text("AGB")
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
                    Text(TextKey.confirm.localized)
                        .font(.cjHeadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding(.top)
                .disabled(termsAccepted == false || privacyAccepted == false)
            }
            .padding()
            .navigationTitle("Updates")
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
