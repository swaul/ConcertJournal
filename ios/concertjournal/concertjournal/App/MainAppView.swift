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

    @State var viewModel: ConcertsViewModel

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
            Tab(TextKey.tabsConcerts.localized, systemImage: "music.note.list", value: NavigationRoute.concerts) {
                ConcertsView(viewModel: viewModel)
            }

            Tab(TextKey.tabsMap.localized, systemImage: "map", value: NavigationRoute.map) {
                MapView()
            }
            
            Tab(TextKey.tabsBuddies.localized, systemImage: "person.2.fill", value: NavigationRoute.buddies) {
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
    
    enum Keys: String, CaseIterable {
        case termsConsent = "com.concertjournal.terms_consent"
        case hasCompletedOnboarding = "hasCompletedOnboarding"
        case isPremiumUser = "isPremiumUser"
        case localStorageKey = "com.concertjournal.localizationVersion"
        case complianceAcceptance = "compliance_acceptance"
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
            self.set(encoded, forKey: Keys.termsConsent.rawValue)
            print("✅ Terms v\(termsVersion) & Privacy v\(privacyVersion) saved")
        } catch {
            print("❌ Failed to encode terms consent: \(error)")
        }
    }
    
    // MARK: - Get Terms Consent
    
    func getTermsConsent() -> TermsConsent? {
        guard let data = self.data(forKey: Keys.termsConsent.rawValue) else {
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
        self.removeObject(forKey: Keys.termsConsent.rawValue)
        print("🗑️ Terms consent cleared")
    }
}
