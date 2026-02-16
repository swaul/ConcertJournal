//
//  BannerView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI
import GoogleMobileAds

// MARK: - Banner Ad Container (with safe area handling)

struct BannerAdContainer<Content: View>: View {

    let content: Content
    let position: BannerPosition

    enum BannerPosition {
        case top
        case bottom
    }

    init(position: BannerPosition = .bottom, @ViewBuilder content: () -> Content) {
        self.position = position
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if position == .top {
                AdaptiveBannerAdView()
            }

            content

            if position == .bottom {
                AdaptiveBannerAdView()
            }
        }
    }
}

// MARK: - Banner Ad View (SwiftUI)

struct BannerAdView: UIViewRepresentable {

    let adUnitID: String
    let adSize: AdSize

    init(adSize: AdSize = AdSizeBanner) {
        self.adUnitID = AdMobManager.shared.bannerAdUnitID
        self.adSize = adSize
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.keyWindow?.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

// MARK: - Adaptive Banner Ad View

struct AdaptiveBannerAdView: View {

    @State private var bannerHeight: CGFloat = 0

    var body: some View {
        if AdMobManager.shared.shouldShowAds {
            BannerAdView(adSize: getAdaptiveAdSize())
                .frame(height: bannerHeight)
                .onAppear {
                    bannerHeight = getAdaptiveAdSize().size.height
                }
        }
    }

    private func getAdaptiveAdSize() -> AdSize {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let width = windowScene?.screen.bounds.width ?? UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }
}
