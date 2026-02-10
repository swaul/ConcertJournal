//
//  DebugView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

#if DEBUG
import SwiftUI

struct DebugLogView: View {
    @State var logger = CJLogger.shared

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logger.logs, id: \.id) { logEntry in
                        Text(logEntry.formattedMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.vertical, 2)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Debug Logs")
        }
    }
}
#endif
