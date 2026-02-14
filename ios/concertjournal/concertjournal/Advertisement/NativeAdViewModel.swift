

// [START create_view_model]
import GoogleMobileAds
import Combine

@Observable
class NativeAdViewModel: NSObject, NativeAdLoaderDelegate {

    var nativeAd: NativeAd?
    private var adLoader: AdLoader!

    func refreshAd() {
        adLoader = AdLoader(
            adUnitID: AdMobManager.shared.inlineAdUnitID,
            // The UIViewController parameter is optional.
            rootViewController: nil,
            adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(Request())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        // Native ad data changes are published to its subscribers.
        self.nativeAd = nativeAd
        nativeAd.delegate = self
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("\(adLoader) failed with error: \(error.localizedDescription)")
    }
}
// [END create_view_model]

// MARK: - GADNativeAdDelegate implementation
extension NativeAdViewModel: NativeAdDelegate {
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }

    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }

    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }

    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
}
