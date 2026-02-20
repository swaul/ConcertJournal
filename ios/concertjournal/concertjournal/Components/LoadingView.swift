//
//  LoadingView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI

struct LoadingView: View {

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2.5)
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
