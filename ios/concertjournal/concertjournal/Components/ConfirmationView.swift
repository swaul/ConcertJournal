//
//  ConfirmationView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import SwiftUI

struct ConfirmationMessage: Identifiable {
    let id = UUID()
    let message: String
}

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    
    init(message: String? = nil) {
        self.message = message ?? "Done"
    }
    
    let message: String
    
    @State private var drawProgress: CGFloat = 0
    @State private var showDone: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            CheckmarkShape()
                .trim(from: 0, to: drawProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 64)
                .contentTransition(.interpolate)
            
            Text(message)
                .font(.cjHeadline)
                .opacity(showDone ? 1 : 0)
                .animation(.easeIn(duration: 0.25), value: showDone)
        }
        .padding(24)
        .onAppear {
            // Animate the checkmark stroke
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
                drawProgress = 1
            }
            // Fade in the label slightly after the stroke completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showDone = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
        .presentationDetents([.height(180)]) // Small sheet height
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // A proportional checkmark path
        let w = rect.width
        let h = rect.height
        
        let start = CGPoint(x: 0.2 * w, y: 0.55 * h)
        let mid = CGPoint(x: 0.45 * w, y: 0.8 * h)
        let end = CGPoint(x: 0.8 * w, y: 0.25 * h)
        
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

