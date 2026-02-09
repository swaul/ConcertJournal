//
//  LoadingSheet.swift
//  concertjournal
//
//  Created by Paul Kühnel on 09.02.26.
//

import SwiftUI

struct LoadingSheet: View {
    
    @Environment(\.dependencies) private var dependencies
    
    let message: String
    
    var body: some View {
        ZStack {
            VStack {
                ProgressView()
                    .tint(dependencies.colorThemeManager.appTint)
                Text(message)
                    .font(.cjBody)
            }
        }
        .frame(height: 250)
        .presentationDetents([.height(250)])
        .interactiveDismissDisabled()
    }
}
