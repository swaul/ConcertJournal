//
//  View+Shake.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import UIKit

extension UIWindow {
    open override func motionEnded(
        _ motion: UIEvent.EventSubtype,
        with event: UIEvent?
    ) {
        guard motion == .motionShake else { return }
        #if DEBUG
        DebugShakeManager.shared.trigger()
        #else
        DebugShakeManager.shared.trigger()
        #endif
    }
}

final class DebugShakeManager {
    static let shared = DebugShakeManager()
    private init() {}

    var onShake: (() -> Void)?

    func trigger() {
        onShake?()
    }
}
