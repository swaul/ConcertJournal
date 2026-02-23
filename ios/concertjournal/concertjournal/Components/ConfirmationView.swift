//
//  ConfirmationView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import SwiftUI
import Combine

struct AdditionalInfo {
    let infos: [String]
}

struct ConfirmationMessage: Identifiable {
    let id = UUID()
    let message: String
    let additionalInfos: AdditionalInfo?
    let completion: (() -> Void)?

    init(message: String, additionalInfos: AdditionalInfo? = nil, completion: (() -> Void)? = nil) {
        self.message = message
        self.additionalInfos = additionalInfos
        self.completion = completion
    }
}

struct ConfirmationView: View {
    @Environment(\.dependencies) private var dependencies

    var completion: (() -> Void)?

    init(message: ConfirmationMessage, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.message = message.message
        self.additionalInfos = message.additionalInfos
        self.completion = message.completion
    }
    
    let message: String
    let additionalInfos: AdditionalInfo?

    @State private var drawProgress: CGFloat = 0
    @State private var showDone: Bool = false
    @Binding private var isPresented: Bool

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
                .frame(maxWidth: .infinity, alignment: .center)

            if let additionalInfos {
                ForEach(additionalInfos.infos, id: \.self) {
                    Text($0)
                }

                Button {
                    if let completion {
                        isPresented = false
                        completion()
                    } else {
                        isPresented = false
                    }
                } label: {
                    Text(TextKey.understood.localized)
                        .font(.cjHeadline)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }

        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
                drawProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showDone = true
            }

            guard additionalInfos == nil else {  return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let completion {
                    isPresented = false
                    completion()
                } else {
                    isPresented = false
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
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

struct AutoTriggerButton: View {
    let title: String
    let duration: TimeInterval
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var isPressed = false
    @State private var hasCanceled = false

    private let accentColor: Color

    init(
        title: String,
        duration: TimeInterval = 5.0,
        accentColor: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.duration = duration
        self.action = action
        self.accentColor = accentColor
        self._timeRemaining = State(initialValue: duration)
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(accentColor.opacity(0.2))

                // Progressive Fill
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor)
                        .frame(width: geometry.size.width * progress)
                        .animation(.linear(duration: 0.1), value: progress)
                }

                // Content
                HStack(spacing: 12) {
                    Text(title)
                        .font(.cjHeadline)
                        .foregroundStyle(.white)

                    if !hasCanceled {
                        Text("\(Int(ceil(timeRemaining)))")
                            .font(.cjTitle2)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .padding()
            }
            .frame(height: 56)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func handleTap() {
        HapticManager.shared.impact(.medium)
        hasCanceled = true
        stopTimer()

        withAnimation(.easeOut(duration: 0.2)) {
            progress = 0
        }

        action()
    }

    private func startTimer() {
        let updateInterval: TimeInterval = 1

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            guard !hasCanceled else {
                stopTimer()
                return
            }

            timeRemaining -= updateInterval
            progress = CGFloat(1 - (timeRemaining / duration))

            if timeRemaining.truncatingRemainder(dividingBy: 1.0) < updateInterval {
                HapticManager.shared.impact(.light)
            }

            if timeRemaining <= 0 {
                stopTimer()
                triggerAction()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func triggerAction() {
        HapticManager.shared.success()
        action()
    }
}

#Preview {
    AutoTriggerButton(title: "Verstanden") {
        print("Fertig!")
    }
}
