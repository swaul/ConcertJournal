import SwiftUI
import Combine

// MARK: - UserDefaults Keys
private enum ColorDefaultsKey {
    static let appTintColor = "AppTintColorRGBA"
}

// MARK: - Codable RGBA container
private struct RGBAColor: Codable, Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat
}

// MARK: - Color <-> RGBA helpers
private extension Color {
    init?(rgba: RGBAColor) {
        self = Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    func toRGBA() -> RGBAColor? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBAColor(r: r, g: g, b: b, a: a)
        #elseif canImport(AppKit)
        let ns = NSColor(self)
        guard let conv = ns.usingColorSpace(.sRGB) else { return nil }
        return RGBAColor(r: conv.redComponent, g: conv.greenComponent, b: conv.blueComponent, a: conv.alphaComponent)
        #else
        return nil
        #endif
    }
}

// MARK: - Persistence API
struct ColorPersistence {
    static func saveAppTint(_ color: Color) {
        guard let rgba = color.toRGBA() else { return }
        do {
            let data = try JSONEncoder().encode(rgba)
            UserDefaults.standard.set(data, forKey: ColorDefaultsKey.appTintColor)
        } catch {
            // Silently ignore encoding errors in release builds
            #if DEBUG
            print("Failed to encode color: \(error)")
            #endif
        }
    }

    static func loadAppTint() -> Color? {
        guard let data = UserDefaults.standard.data(forKey: ColorDefaultsKey.appTintColor) else { return nil }
        do {
            let rgba = try JSONDecoder().decode(RGBAColor.self, from: data)
            return Color(rgba: rgba)
        } catch {
            #if DEBUG
            print("Failed to decode color: \(error)")
            #endif
            return nil
        }
    }

    static func clearAppTint() {
        UserDefaults.standard.removeObject(forKey: ColorDefaultsKey.appTintColor)
    }
}

// MARK: - Observable Theme Manager

@Observable
@MainActor
final class ColorThemeManager {
    var appTint: Color {
        didSet {
            ColorPersistence.saveAppTint(appTint)
        }
    }

    init(defaultTint: Color = .accentColor) {
        if let saved = ColorPersistence.loadAppTint() {
            self.appTint = saved
        } else {
            self.appTint = defaultTint
        }
    }
}

// MARK: - EnvironmentKey for convenience
private struct AppTintColorKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

extension EnvironmentValues {
    var appTintColor: Color {
        get { self[AppTintColorKey.self] }
        set { self[AppTintColorKey.self] = newValue }
    }
}
