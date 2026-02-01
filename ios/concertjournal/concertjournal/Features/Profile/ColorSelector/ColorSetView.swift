import SwiftUI

private extension Color {
    func rgba() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r,g,b,a)
        #elseif canImport(AppKit)
        let ns = NSColor(self)
        guard let c = ns.usingColorSpace(.sRGB) else { return nil }
        return (c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
        #else
        return nil
        #endif
    }
}

private func isDisallowedBlackOrWhite(_ color: Color, epsilon: CGFloat = 0.02) -> Bool {
    guard let c = color.rgba() else { return false }
    // Consider near-black or near-white as disallowed
    let nearBlack = c.r < epsilon && c.g < epsilon && c.b < epsilon
    let nearWhite = (1 - c.r) < epsilon && (1 - c.g) < epsilon && (1 - c.b) < epsilon
    return nearBlack || nearWhite
}

struct ColorSetView: View {
    @EnvironmentObject private var colorTheme: ColorThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTintColor) private var appTint
    @State private var tempColor: Color = .accentColor
    
    private var isInvalidSelection: Bool { isDisallowedBlackOrWhite(tempColor) }
    
    var body: some View {
            Form {
                Section(header: Text("Preview").font(.cjBody)) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(tempColor)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().stroke(.secondary, lineWidth: 0.5)
                            )
                        Text("This is your app color")
                            .font(.cjBody)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Pick a color").font(.cjBody)) {
                    ColorPicker("App Color", selection: $tempColor, supportsOpacity: true)
                        .tint(tempColor)
                    if isInvalidSelection {
                        Text("Black and white are not allowed.")
                            .font(.cjFootnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            let candidate: Color = .accentColor
                            if isDisallowedBlackOrWhite(candidate) {
                                tempColor = .blue
                            } else {
                                tempColor = candidate
                            }
                        }
                    } label: {
                        Label("Reset to System Accent", systemImage: "arrow.counterclockwise")
                            .font(.cjBody)
                    }
                }
            }
            .navigationTitle("App Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Abbrechen")
                            .font(.cjBody)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard !isInvalidSelection else { return }
                        withAnimation(.easeInOut) {
                            colorTheme.appTint = tempColor
                        }
                        dismiss()
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                            .bold()
                    }
                    .tint(tempColor)
                    .disabled(isInvalidSelection)
                }
            }
            .tint(tempColor)
            .onAppear {
                // Start with the current app tint
                tempColor = colorTheme.appTint
            }
    }
}

#Preview {
    ColorSetView()
        .environmentObject(ColorThemeManager())
}

