//
//  FullScreenImagePagerView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 13.01.26.
//

import Foundation
import SwiftUI
import Zoomable

struct FullscreenImagePagerView: View {
    let imageUrls: [ConcertImage]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State var hideButton: Bool = true

    init(imageUrls: [ConcertImage], startIndex: Int) {
        self.imageUrls = imageUrls
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(imageUrls.indices, id: \.self) { index in
                    AsyncImage(url: imageUrls[index].url) { image in
                        if let image = image.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .zoomable()
                        } else {
                            ProgressView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                if !hideButton {
                    HStack {
                        Spacer()
                        Button {
                            HapticManager.shared.navigationBack()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .imageScale(.large)
                        }
                        .buttonStyle(.glass)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation {
                hideButton = false
            }
        }
        .onTapGesture {
            withAnimation {
                hideButton.toggle()
            }
        }
    }
}
