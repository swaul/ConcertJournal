//
//  MarqueeText.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI

struct MarqueeText: View {

    let text: String
    let font: Font
    let spacing: CGFloat

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var fullWidth: CGFloat = 0
    @State private var showMarqueeLabels: Bool = false

    init(_ text: String, font: Font = .body, spacing: CGFloat = 12) {
        self.text = text
        self.font = font
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                if showMarqueeLabels {
                    ForEach(0..<2, id: \.self) { index in
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize()
                    }
                } else {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                        .background(
                            GeometryReader { textGeometry in
                                Color.clear.onAppear {
                                    textWidth = textGeometry.size.width
                                }
                            }
                        )
                }
            }
            .padding(.leading, 12)
            .offset(x: offset)
            .onChange(of: textWidth, { _, newValue in
                if newValue > geometry.size.width {
                    showMarqueeLabels = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        startMarquee()
                    }
                }
            })
        }
        .clipped()
    }

    private func startMarquee() {
        withAnimation(.linear(duration: 8.0)) {
            offset = -(textWidth + spacing)
        }
    }
}
