import SwiftUI
import UIKit

/// Signage blue and amber on cool paper; rounded display type for Italian words, mono for anything "printed".
enum Theme {
    static let bg = adaptive(light: UIColor(red: 0.945, green: 0.949, blue: 0.933, alpha: 1), dark: UIColor(red: 0.055, green: 0.078, blue: 0.133, alpha: 1))
    static let surface = adaptive(light: .white, dark: UIColor(red: 0.090, green: 0.122, blue: 0.212, alpha: 1))
    static let surface2 = adaptive(light: UIColor(red: 0.906, green: 0.914, blue: 0.886, alpha: 1), dark: UIColor(red: 0.122, green: 0.161, blue: 0.267, alpha: 1))
    static let ink = adaptive(light: UIColor(red: 0.078, green: 0.110, blue: 0.180, alpha: 1), dark: UIColor(red: 0.929, green: 0.941, blue: 0.965, alpha: 1))
    static let ink2 = adaptive(light: UIColor(red: 0.357, green: 0.392, blue: 0.471, alpha: 1), dark: UIColor(red: 0.616, green: 0.659, blue: 0.761, alpha: 1))
    static let rule = adaptive(light: UIColor.black.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.13))
    static let blue = adaptive(light: UIColor(red: 0.165, green: 0.310, blue: 0.561, alpha: 1), dark: UIColor(red: 0.498, green: 0.643, blue: 0.902, alpha: 1))
    static let onBlue = adaptive(light: .white, dark: UIColor(red: 0.055, green: 0.078, blue: 0.133, alpha: 1))
    static let blueSoft = adaptive(light: UIColor(red: 0.863, green: 0.894, blue: 0.961, alpha: 1), dark: UIColor(red: 0.137, green: 0.212, blue: 0.345, alpha: 1))
    // Dark amber is a muted ochre so it reads as an accent, not a highlighter, on navy.
    static let amber = adaptive(light: UIColor(red: 0.776, green: 0.494, blue: 0.039, alpha: 1), dark: UIColor(red: 0.851, green: 0.643, blue: 0.369, alpha: 1))
    static let amberSoft = adaptive(light: UIColor(red: 0.984, green: 0.937, blue: 0.827, alpha: 1), dark: UIColor(red: 0.196, green: 0.176, blue: 0.149, alpha: 1))
    /// The dark "readout" block (clock, results). Navy ink in light mode; a raised navy in dark mode instead of a white slab.
    static let slab = adaptive(light: UIColor(red: 0.078, green: 0.110, blue: 0.180, alpha: 1), dark: UIColor(red: 0.149, green: 0.200, blue: 0.322, alpha: 1))
    static let onSlab = adaptive(light: UIColor(red: 0.945, green: 0.949, blue: 0.933, alpha: 1), dark: UIColor(red: 0.929, green: 0.941, blue: 0.965, alpha: 1))
    static let green = adaptive(light: UIColor(red: 0.122, green: 0.478, blue: 0.341, alpha: 1), dark: UIColor(red: 0.361, green: 0.780, blue: 0.604, alpha: 1))
    static let greenSoft = adaptive(light: UIColor(red: 0.867, green: 0.941, blue: 0.902, alpha: 1), dark: UIColor(red: 0.082, green: 0.204, blue: 0.149, alpha: 1))
    static let red = adaptive(light: UIColor(red: 0.722, green: 0.224, blue: 0.180, alpha: 1), dark: UIColor(red: 0.941, green: 0.475, blue: 0.424, alpha: 1))
    static let redSoft = adaptive(light: UIColor(red: 0.969, green: 0.867, blue: 0.855, alpha: 1), dark: UIColor(red: 0.263, green: 0.125, blue: 0.110, alpha: 1))


    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

