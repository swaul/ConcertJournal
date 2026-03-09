//
//  LoadingView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI
import DotLottie

struct LoadingView: View {

    var body: some View {
        VStack(spacing: 24) {
            FlowerLoading()
            Text(TextKey.stateLoading.localized)
                .font(.cjTitle2)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.background
        }
        .ignoresSafeArea()
    }

}

struct TextLessLoadingView: View {


    var body: some View {
        VStack(spacing: 24) {
            FlowerLoading()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.background
        }
        .ignoresSafeArea()
    }
    
}

#Preview {
    TextLessLoadingView()
}

struct SearchingView: View {

    @Environment(\.dependencies) var dependencies

    var searchContent: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolEffect(.breathe)
                .frame(width: 48)
                .foregroundStyle(dependencies.colorThemeManager.appTint)

            Text("Suche \(searchContent)...")
                .font(.cjTitle2)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.background
        }
        .ignoresSafeArea()
    }

}

//#Preview {
//    SearchingView(searchContent: "Künstler")
//}

struct FlowerLoading: View {

    var body: some View {
        let lottie = DotLottieAnimation(
            fileName: "FlowerLoading",
            config: AnimationConfig(autoplay: true, loop: true)
        )
        lottie.framerate = 60

        return lottie.view()
    }
}
