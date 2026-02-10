//
//  LoadingView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI

struct LoadingView: View {

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2.5)
            Text("Laden...")
                .font(.cjTitle2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
