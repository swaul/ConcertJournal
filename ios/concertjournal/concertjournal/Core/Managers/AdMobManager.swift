//
//  AdMobManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

// MARK: - AdMob Manager

@Observable
class AdMobManager {

    static let shared = AdMobManager()

    // MARK: - Properties

    var isInitialized = false
    var isPremiumUser = false

    // Ad Unit IDs (Ersetze mit deinen echten IDs aus AdMob Console)
#if DEBUG
    // Test IDs
    let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    let inlineAdUnitID = "ca-app-pub-3940256099942544/3986624511"
//    let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
#else
    // Production IDs (WICHTIG: Ersetze diese!)
    let bannerAdUnitID = "ca-app-pub-7897142018085073~3599198457"
    let interstitialAdUnitID = "ca-app-pub-7897142018085073~3599198457"
    let inlineAdUnitID = "ca-app-pub-7897142018085073~3599198457"
//    let rewardedAdUnitID = "ca-app-pub-XXXXXX/XXXXXX"
#endif

    // Interstitial Ad
    private var interstitialAd: InterstitialAd?
    private var isLoadingInterstitial = false

    // Rewarded Ad
    private var rewardedAd: RewardedAd?
    private var isLoadingRewarded = false

    // Ad frequency control
    private var interstitialShowCount = 0
    private let showInterstitialEvery = 5 // Zeige alle 5 Actions

    // MARK: - Initialization

    private init() {
        checkPremiumStatus()
    }

    func initialize() {
        guard !isInitialized else { return }

        Task {
            let status: InitializationStatus = await MobileAds.shared.start()

            print(status.adapterStatusesByClassName)
            self.isInitialized = true
            logInfo("AdMob initialized", category: .ads)

            // Preload ads
            await loadInterstitialAd()
//            self.loadRewardedAd()

            // Request ATT Permission (App Tracking Transparency)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.requestTrackingPermission()
            }
        }
    }

    private func requestTrackingPermission() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                logInfo("Tracking permission: \(status.rawValue)", category: .ads)
            }
        }
    }

    // MARK: - Premium Check

    func checkPremiumStatus() {
        // Check if user has premium subscription
        isPremiumUser = UserDefaults.standard.bool(forKey: "isPremiumUser")
    }

    func setPremium(_ isPremium: Bool) {
        isPremiumUser = isPremium
        UserDefaults.standard.set(isPremium, forKey: "isPremiumUser")
    }

    var shouldShowAds: Bool {
        !isPremiumUser
    }

    // MARK: - Interstitial Ads

    func loadInterstitialAd() async {
        guard shouldShowAds, !isLoadingInterstitial else { return }

        isLoadingInterstitial = true

        do {
            interstitialAd = try await InterstitialAd.load(with: interstitialAdUnitID, request: Request())
            logInfo("Interstitial ad loaded", category: .ads)
            isLoadingInterstitial = false
        } catch {
            logError("Failed to load interstitial ad", error: error, category: .ads)
            isLoadingInterstitial = false
        }
    }

    func showInterstitialAd(from viewController: UIViewController?) async {
        guard shouldShowAds else { return }

        // Frequency control
        interstitialShowCount += 1
        guard interstitialShowCount % showInterstitialEvery == 0 else { return }

        guard let ad = interstitialAd else {
            logInfo("Interstitial ad not ready", category: .ads)
            await loadInterstitialAd() // Preload next
            return
        }

        guard let vc = viewController ?? UIApplication.shared.keyWindow?.rootViewController else {
            logInfo("Was not able to get rootViewController", category: .ads)
            return
        }

        ad.present(from: vc)
        logInfo("Interstitial ad shown", category: .ads)

        // Preload next ad
        interstitialAd = nil
        await loadInterstitialAd()
    }

    // MARK: - Inline Ad

    // MARK: - Rewarded Ads

//    func loadRewardedAd() {
//        guard !isLoadingRewarded else { return }
//
//        isLoadingRewarded = true
//
//        let request = AdManagerRequest()
//
//        GADRewardedAd.load(
//            withAdUnitID: rewardedAdUnitID,
//            request: request
//        ) { [weak self] ad, error in
//            self?.isLoadingRewarded = false
//
//            if let error = error {
//                logError("Failed to load rewarded ad", error: error, category: .ads)
//                return
//            }
//
//            self?.rewardedAd = ad
//            logInfo("Rewarded ad loaded", category: .ads)
//        }
//    }
//
//    func showRewardedAd(
//        from viewController: UIViewController?,
//        onRewarded: @escaping (Int) -> Void
//    ) {
//        guard let ad = rewardedAd else {
//            logInfo("Rewarded ad not ready", category: .ads)
//            loadRewardedAd()
//            return
//        }
//
//        guard let vc = viewController ?? UIApplication.shared.keyWindow?.rootViewController else {
//            return
//        }
//
//        ad.present(fromRootViewController: vc) {
//            let reward = ad.adReward
//            logInfo("User earned reward: \(reward.amount) \(reward.type)", category: .ads)
//            onRewarded(reward.amount.intValue)
//        }
//
//        // Preload next ad
//        rewardedAd = nil
//        loadRewardedAd()
//    }
//
//    var isRewardedAdReady: Bool {
//        rewardedAd != nil
//    }
}

// MARK: - Interstitial Ad Trigger

extension View {

    /// Shows interstitial ad after action
    func showInterstitialAfterAction() -> some View {
        self.onDisappear {
            logInfo("Attempting to show Interstitial Ad after action", category: .ads)
            Task {
                await AdMobManager.shared.showInterstitialAd(from: nil)
            }
        }
    }
}

// MARK: - Rewarded Ad Button

//struct WatchAdForFeatureButton: View {
//
//    let featureName: String
//    let onRewarded: () -> Void
//
//    @State private var showingAd = false
//
//    var body: some View {
//        Button {
//            showingAd = true
//        } label: {
//            HStack {
//                Image(systemName: "play.rectangle.fill")
//                Text("Video ansehen für \(featureName)")
//                    .font(.cjHeadline)
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.green)
//            .foregroundColor(.white)
//            .cornerRadius(12)
//        }
//        .disabled(!AdMobManager.shared.isRewardedAdReady)
//        .opacity(AdMobManager.shared.isRewardedAdReady ? 1.0 : 0.5)
//        .onChange(of: showingAd) { oldValue, newValue in
//            if newValue {
//                AdMobManager.shared.showRewardedAd(from: nil) { _ in
//                    onRewarded()
//                    showingAd = false
//                }
//            }
//        }
//    }
//}

// MARK: - UIApplication Extension

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
