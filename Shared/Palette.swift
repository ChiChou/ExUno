import SwiftUI
import UIKit

/// Near-white paper, coral, apricot and sage, shared by the app and widgets.
enum Theme {
    static let bg = adaptive(light: 0xFAF9F5, dark: 0x201E1B)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x2C2925)
    static let surface2 = adaptive(light: 0xF0EDE6, dark: 0x38332E)
    static let ink = adaptive(light: 0x302D28, dark: 0xFAF9F5)
    static let ink2 = adaptive(light: 0x6D665E, dark: 0xBFB7AC)
    static let rule = adaptive(light: UIColor.black.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.13))
    // Deeper coral keeps white button labels and small accent text legible.
    static let accent = adaptive(light: 0xBA4634, dark: 0xF69A83)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x302019)
    static let accentSoft = adaptive(light: 0xFCEAE4, dark: 0x49312A)
    // Warm apricot accents use a deeper shade for small text in light mode.
    static let amber = adaptive(light: 0x925518, dark: 0xF4B477)
    static let amberSoft = adaptive(light: 0xFFF0DE, dark: 0x443424)
    /// Warm charcoal readouts for clocks and conversion results.
    static let slab = adaptive(light: 0x302D28, dark: 0x3D3730)
    static let onSlab = adaptive(light: 0xFAF9F5, dark: 0xFAF9F5)
    static let green = adaptive(light: 0x526B46, dark: 0xB0C49D)
    static let greenSoft = adaptive(light: 0xEAF0E4, dark: 0x303D2A)
    static let red = adaptive(light: 0xA32D49, dark: 0xF4A1B4)
    static let redSoft = adaptive(light: 0xFAE6EC, dark: 0x482C35)


    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        adaptive(light: uiColor(light), dark: uiColor(dark))
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

