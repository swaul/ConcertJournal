//
//  ConfirmationView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import SwiftUI
import Combine

struct AdditionalInfo {
    let infos: [String]
}

struct ConfirmationMessage: Identifiable {
    let id = UUID()
    let message: String
    let additionalInfos: AdditionalInfo?
    let completion: (() -> Void)?

    init(message: String, additionalInfos: AdditionalInfo? = nil, completion: (() -> Void)? = nil) {
        self.message = message
        self.additionalInfos = additionalInfos
        self.completion = completion
    }
}

struct ConfirmationView: View {
    @Environment(\.dependencies) private var dependencies

    var completion: (() -> Void)?

    init(message: ConfirmationMessage, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.message = message.message
        self.additionalInfos = message.additionalInfos
        self.completion = message.completion
    }
    
    let message: String
    let additionalInfos: AdditionalInfo?

    @State private var showDone: Bool = false
    @Binding private var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            if showDone {
                Image(systemName: "checkmark.diamond")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.green)
                    .symbolEffect(.drawOn.byLayer)
            }
            
            Text(message)
                .font(.cjHeadline)
                .opacity(showDone ? 1 : 0)
                .animation(.easeIn(duration: 0.25), value: showDone)
                .frame(maxWidth: .infinity, alignment: .center)

            if let additionalInfos {
                ForEach(additionalInfos.infos, id: \.self) {
                    Text($0)
                }

                Button {
                    if let completion {
                        isPresented = false
                        completion()
                    } else {
                        isPresented = false
                    }
                } label: {
                    Text(TextKey.genericUnderstood.localized)
                        .font(.cjHeadline)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }

        }
        .padding(24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showDone = true
            }

            guard additionalInfos == nil else {  return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let completion {
                    isPresented = false
                    completion()
                } else {
                    isPresented = false
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
