//
//  ConcertBackgroundImage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 06.01.26.
//

import SwiftUI

struct ConcertBackgroundImage: View {

    let width: CGFloat
    let imageUrl: String

    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { result in
            result.image?
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .frame(width: width)
        .overlay {
            LinearGradient(
                colors: [Color.clear, Color.clear, Color("backgroundColor").opacity(0.15), Color("backgroundColor").opacity(0.35), Color("backgroundColor").opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color("backgroundColor"), location: 0.0),
                    .init(color: Color("backgroundColor"), location: 0.75),
                    .init(color: Color("backgroundColor"), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(width: width)
        .ignoresSafeArea()
    }
}

struct ParallaxHeader<Content: View, Space: Hashable>: View {
    let content: () -> Content
    let coordinateSpace: Space
    let defaultHeight: CGFloat

    init(
        coordinateSpace: Space,
        defaultHeight: CGFloat,
        @ViewBuilder _ content: @escaping () -> Content
    ) {
        self.content = content
        self.coordinateSpace = coordinateSpace
        self.defaultHeight = defaultHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let offset = offset(for: proxy)
            let heightModifier = heightModifier(for: proxy)
            let blurRadius = min(
                heightModifier / 20,
                max(10, heightModifier / 20)
            )
            content()
                .edgesIgnoringSafeArea(.horizontal)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height + heightModifier
                )
                .offset(y: offset)
                .blur(radius: blurRadius)
        }
        .frame(height: defaultHeight)
    }

    private func offset(for proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: .named(coordinateSpace))
        if frame.minY < 0 {
            return -frame.minY * 0.8
        }
        return -frame.minY
    }

    private func heightModifier(for proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: .named(coordinateSpace))
        return max(0, frame.minY)
    }
}
