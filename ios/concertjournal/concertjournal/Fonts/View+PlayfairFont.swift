//
//  View+PlayfairFont.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI

extension View {
    func fontPlayfairRegular(_ size: CGFloat) -> some View {
        self.font(.custom("PlayfairDisplay-Regular", size: size))
    }

    func fontPlayfairBold(_ size: CGFloat) -> some View {
        self.font(.custom("PlayfairDisplay-Bold", size: size))
    }

    func fontPlayfairItalic(_ size: CGFloat) -> some View {
        self.font(.custom("PlayfairDisplay-Italic", size: size))
    }

    func fontPlayfairSCRegular(_ size: CGFloat) -> some View {
        self.font(.custom("PlayfairDisplaySC-Regular", size: size))
    }
}

extension Font {
    static let cjLargeTitle = Font.custom("PlayfairDisplay-Bold", size: 34)
    static let cjTitleF = Font.custom("PlayfairDisplay-Regular", size: 28)
    static let cjTitle = Font.custom("Manrope-Bold", size: 28)
    static let cjTitle2 = Font.custom("Manrope-Semibold", size: 22)

    static let cjBody = Font.custom("Manrope-Regular", size: 17)
    static let cjCaption = Font.custom("Manrope-Regular", size: 12)
    static let cjHeadline = Font.custom("Manrope-Bold", size: 17)
    static let cjFootnote = Font.custom("Manrope-Regular", size: 13)
}
