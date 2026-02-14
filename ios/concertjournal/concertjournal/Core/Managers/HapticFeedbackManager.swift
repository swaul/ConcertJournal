//
//  HapticFeedbackManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 13.02.26.
//

import UIKit
import SwiftUI

// MARK: - Haptic Feedback Manager

class HapticManager {

    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    enum ImpactStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid

        var generator: UIImpactFeedbackGenerator {
            switch self {
            case .light:
                return UIImpactFeedbackGenerator(style: .light)
            case .medium:
                return UIImpactFeedbackGenerator(style: .medium)
            case .heavy:
                return UIImpactFeedbackGenerator(style: .heavy)
            case .soft:
                return UIImpactFeedbackGenerator(style: .soft)
            case .rigid:
                return UIImpactFeedbackGenerator(style: .rigid)
            }
        }
    }

    func impact(_ style: ImpactStyle = .medium) {
        let generator = style.generator
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Context-Specific Feedback

    // Navigation
    func navigationTap() {
        impact(.light)
    }

    func navigationBack() {
        impact(.medium)
    }

    // Actions
    func buttonTap() {
        impact(.light)
    }

    func toggleSwitch() {
        impact(.medium)
    }

    func delete() {
        impact(.heavy)
    }

    // Lists & Pickers
    func listItemTap() {
        impact(.light)
    }

    func pickerSelection() {
        selection()
    }

    func swipeAction() {
        impact(.medium)
    }

    // Forms & Input
    func textFieldFocus() {
        impact(.soft)
    }

    func formSubmit() {
        impact(.medium)
    }

    // Results
    func operationSuccess() {
        success()
    }

    func operationError() {
        error()
    }

    func operationWarning() {
        warning()
    }

    // Gestures
    func longPress() {
        impact(.heavy)
    }

    func drag() {
        impact(.light)
    }

    func dragEnd() {
        impact(.medium)
    }

    // Special
    func refresh() {
        impact(.soft)
    }

    func shareSheet() {
        impact(.light)
    }

    func photoCapture() {
        impact(.rigid)
    }
}

// MARK: - SwiftUI View Extension

extension View {

    // MARK: - Basic Haptics

    /// Add haptic feedback on tap
    func hapticTap(_ style: HapticManager.ImpactStyle = .light) -> some View {
        self.onTapGesture {
            HapticManager.shared.impact(style)
        }
    }

    /// Add haptic feedback to button
    func hapticButton(_ style: HapticManager.ImpactStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.shared.impact(style)
            }
        )
    }

    /// Add haptic feedback on long press
    func hapticLongPress(minimumDuration: Double = 0.5) -> some View {
        self.simultaneousGesture(
            LongPressGesture(minimumDuration: minimumDuration)
                .onEnded { _ in
                    HapticManager.shared.longPress()
                }
        )
    }

    // MARK: - Contextual Haptics

    /// Navigation item tap feedback
    func navigationHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.shared.navigationTap()
            }
        )
    }

    /// List item selection feedback
    func listItemHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.shared.listItemTap()
            }
        )
    }

    /// Delete action feedback
    func deleteHaptic() -> some View {
        self.onTapGesture {
            HapticManager.shared.delete()
        }
    }

    /// Success feedback
    func successHaptic() -> some View {
        self.onAppear {
            HapticManager.shared.success()
        }
    }

    /// Error feedback
    func errorHaptic() -> some View {
        self.onAppear {
            HapticManager.shared.error()
        }
    }
}

// MARK: - Button Style with Haptics

struct HapticButtonStyle: ButtonStyle {

    let impactStyle: HapticManager.ImpactStyle

    init(impactStyle: HapticManager.ImpactStyle = .light) {
        self.impactStyle = impactStyle
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.impact(impactStyle)
                }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var haptic: HapticButtonStyle {
        HapticButtonStyle()
    }

    static func haptic(_ style: HapticManager.ImpactStyle) -> HapticButtonStyle {
        HapticButtonStyle(impactStyle: style)
    }
}

// MARK: - Toggle with Haptics

struct HapticToggleStyle: ToggleStyle {

    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .onChange(of: configuration.isOn) { _, _ in
                HapticManager.shared.toggleSwitch()
            }
    }
}

extension ToggleStyle where Self == HapticToggleStyle {
    static var haptic: HapticToggleStyle {
        HapticToggleStyle()
    }
}

// MARK: - Picker with Haptics

struct HapticPicker<SelectionValue: Hashable, Content: View>: View {

    @Binding var selection: SelectionValue
    let content: Content

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        Picker("", selection: $selection) {
            content
        }
        .onChange(of: selection) { _, _ in
            HapticManager.shared.pickerSelection()
        }
    }
}
