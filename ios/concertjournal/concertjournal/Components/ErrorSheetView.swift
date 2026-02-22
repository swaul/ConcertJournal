//
//  ErrorSheetView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 17.02.26.
//

import Foundation
import SwiftUI

struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
    let additionalInfos: AdditionalInfo?

    init(message: String, additionalInfos: AdditionalInfo? = nil) {
        self.message = message
        self.additionalInfos = additionalInfos
    }
}

struct ErrorSheetView: View {
    @Environment(\.dependencies) private var dependencies

    init(message: ErrorMessage, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.message = message.message
        self.additionalInfos = message.additionalInfos
    }

    let message: String
    let additionalInfos: AdditionalInfo?

    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.xmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .padding(.top)

            Text(message)
                .font(.cjHeadline)
                .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    isPresented = false
                } label: {
                    Text(TextKey.understood.localized)
                        .font(.cjHeadline)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
        }
        .padding(24)
        .presentationDragIndicator(.visible)
    }
}
