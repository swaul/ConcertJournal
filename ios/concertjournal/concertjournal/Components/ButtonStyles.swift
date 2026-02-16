//
//  ButtonStyles.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

// MARK: - Custom Button Styles
struct ModernButtonStyle: ButtonStyle {
    enum Style {
        case prominent
        case glass
    }

    let style: Style
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                if style == .prominent {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
            .foregroundStyle(style == .prominent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.15), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}

struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.2 : 0.3), radius: configuration.isPressed ? 8 : 16, x: 0, y: configuration.isPressed ? 4 : 8)
    }
}
