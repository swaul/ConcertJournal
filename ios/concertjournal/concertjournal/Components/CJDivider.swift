//
//  CJDivider.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.02.26.
//

import SwiftUI

public struct CJDivider: View {

    let title: String
    let image: Image?

    public var body: some View {
        HStack(alignment: .center) {
            if let image {
                image
            }
            Text(title)
                .font(.cjHeadline)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color("DividerColor"))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

}
