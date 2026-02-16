//
//  ScrollOfsetPreferenceKey.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
