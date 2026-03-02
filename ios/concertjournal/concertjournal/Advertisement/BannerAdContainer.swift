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
    
    let horizontalPadding: CGFloat
    let content: Content
    let position: BannerPosition
    
    enum BannerPosition {
        case top
        case bottom
    }
    
    init(position: BannerPosition = .bottom, horizontalPadding: CGFloat, @ViewBuilder content: () -> Content) {
        self.position = position
        self.horizontalPadding = horizontalPadding
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if position == .top {
                AdaptiveBannerAdView(horizontalPadding: horizontalPadding)
            }
            
            content
            
            if position == .bottom {
                AdaptiveBannerAdView(horizontalPadding: horizontalPadding)
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
    
    let horizontalPadding: CGFloat
    @State private var bannerHeight: CGFloat = 0
    @State private var bannerWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        if AdMobManager.shared.shouldShowAds {
            BannerAdView(adSize: getAdaptiveAdSize())
                .frame(width: bannerWidth - horizontalPadding, height: bannerHeight)
                .onAppear {
                    updateBannerHeight()
                }
                .onChange(of: horizontalSizeClass) { _, _ in
                    updateBannerHeight()
                }
                .onChange(of: verticalSizeClass) { _, _ in
                    updateBannerHeight()
                }
        }
    }
    
    private func updateBannerHeight() {
        let adSize = getAdaptiveAdSize()
        bannerHeight = adSize.size.height
        bannerWidth = adSize.size.width
    }
    
    private func getAdaptiveAdSize() -> AdSize {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let width = windowScene?.screen.bounds.width ?? (verticalSizeClass == .compact ? UIScreen.main.bounds.width : UIScreen.main.bounds.height)
        return largeAnchoredAdaptiveBanner(width: width)
    }
}
