import SwiftUI
import UIKit

// MARK: - Small reusable pieces

struct Tag: View {
    enum Style { case plain, level, pos, gender }
    let text: String
    var style: Style = .plain
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    private var fg: Color {
        switch style {
        case .plain: return Theme.ink2
        case .level: return Theme.amber
        case .pos: return Theme.green
        case .gender: return Theme.accent
        }
    }
    private var bg: Color {
        switch style {
        case .plain: return Theme.surface2
        case .level: return Theme.amberSoft
        case .pos: return Theme.greenSoft
        case .gender: return Theme.accentSoft
        }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.ink2
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11.5, weight: .semibold)).tracking(1.1).foregroundStyle(color)
    }
}

/// Speaker button; highlights while its text is being spoken.
struct SpeakButton: View {
    @Environment(Speech.self) private var speech
    let text: String
    var small = false
    var onDark = false
    private var id: String { "speak:" + text }
    var body: some View {
        Button {
            if speech.speakingID == id { speech.stop() } else { speech.speak(text, id: id) }
        } label: {
            Image(systemName: speech.speakingID == id ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .font(.system(size: small ? 13 : 16, weight: .semibold))
                .frame(width: small ? 32 : 40, height: small ? 32 : 40)
                .background(background, in: Circle())
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Listen")
    }
    private var active: Bool { speech.speakingID == id }
    private var background: Color { active ? Theme.amber : (onDark ? Color.white.opacity(0.14) : Theme.surface2) }
    private var foreground: Color { active ? Theme.ink : (onDark ? Theme.bg : Theme.ink) }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

enum PillStyle { case primary, neutral, ghost, good, bad, amber }

struct Pill: ButtonStyle {
    var style: PillStyle = .neutral
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 14 : 16, weight: .semibold))
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: compact ? 34 : 46)
            .frame(maxWidth: (style == .ghost && compact) ? nil : CGFloat.infinity)
            .background(bg, in: Capsule())
            .overlay(Capsule().stroke(style == .ghost ? Theme.rule : .clear, lineWidth: 1))
            .foregroundStyle(fg)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
    private var bg: Color {
        switch style {
        case .primary: return Theme.accent
        case .neutral: return Theme.surface2
        case .ghost: return .clear
        case .good: return Theme.greenSoft
        case .bad: return Theme.redSoft
        case .amber: return Theme.amberSoft
        }
    }
    private var fg: Color {
        switch style {
        case .primary: return Theme.onAccent
        case .neutral, .ghost: return Theme.ink
        case .good: return Theme.green
        case .bad: return Theme.red
        case .amber: return Theme.amber
        }
    }
}

struct Chip: View {
    let text: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 13).frame(minHeight: 34)
                .background(on ? Theme.ink : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(on ? Theme.ink : Theme.rule, lineWidth: 1))
                .foregroundStyle(on ? Theme.bg : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

/// Dark "readout" block with the Italian result, copy and speak actions.
struct Readout: View {
    let label: String
    let text: String
    var sub: String? = nil
    var minimumTextLines = 1
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: label, color: Theme.onSlab.opacity(0.6))
            Text(text).font(Theme.display(22, weight: .semibold)).foregroundStyle(Theme.onSlab)
                .lineLimit(minimumTextLines...)
                .fixedSize(horizontal: false, vertical: true)
            if let sub { Text(sub).font(Theme.mono(13)).foregroundStyle(Theme.onSlab.opacity(0.65)) }
            HStack(spacing: 8) {
                Spacer()
                Button { UIPasteboard.general.string = text } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 14, weight: .semibold)).frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.14), in: Circle()).foregroundStyle(Theme.onSlab)
                }.buttonStyle(.plain).accessibilityLabel("Copy")
                SpeakButton(text: text, onDark: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.slab, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ErrorReadout: View {
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Attenzione", color: Theme.red)
            Text(message).foregroundStyle(Theme.red)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AltRow: View {
    let label: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: label)
                Text(text).font(.system(size: 16, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            SpeakButton(text: text, small: true)
        }
        .padding(.vertical, 10).padding(.leading, 14).padding(.trailing, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

struct Hint: View {
    let text: String
    var body: some View { Text(text).font(.footnote).foregroundStyle(Theme.ink2) }
}

struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.display(24)).foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.ink2)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

/// Big mono text field for numbers.
struct BigField: View {
    @Binding var text: String
    var placeholder: String
    var keyboard: UIKeyboardType = .decimalPad
    var prefix: String? = nil
    var suffix: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            if let prefix { Text(prefix).font(Theme.mono(24)).foregroundStyle(Theme.ink2) }
            if let suffix {
                GeometryReader { geometry in
                    let numberWidth = ((text.isEmpty ? placeholder : text) as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 26, weight: .medium)]).width
                    let suffixWidth = (suffix as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)]).width
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        field.frame(width: min(numberWidth + 3, max(44, geometry.size.width - suffixWidth)))
                        Text(suffix).font(Theme.mono(18)).foregroundStyle(Theme.ink2.opacity(0.7))
                            .fixedSize().allowsHitTesting(false)
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity)
                }.frame(height: 62)
            } else { field }
        }
        .padding(.horizontal, 16).frame(minHeight: 62)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }

    private var field: some View {
        TextField(placeholder, text: $text)
            .font(Theme.mono(26))
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}

extension View {
    func pageBackground() -> some View { background(Theme.bg.ignoresSafeArea()) }
}

/// Two-thumb level range. Drag either thumb, or tap a level to move the nearest
/// thumb there; the selection is always a contiguous span. VoiceOver adjusts each thumb with swipe up/down.
struct LevelRangeSlider: View {
    let levels: [String]
    let lower: Int
    let upper: Int
    let onChange: (Int, Int) -> Void
    @State private var active: Thumb?
    private enum Thumb { case lower, upper }
    private let inset: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - inset * 2, 1)
            let step = usable / CGFloat(max(levels.count - 1, 1))
            let x = { (i: Int) in inset + CGFloat(i) * step }
            ZStack(alignment: .topLeading) {
                Capsule().fill(Theme.rule).frame(width: usable, height: 4).position(x: width / 2, y: 16)
                Capsule().fill(Theme.accent).frame(width: max(x(upper) - x(lower), 4), height: 4).position(x: (x(lower) + x(upper)) / 2, y: 16)
                ForEach(levels.indices, id: \.self) { i in
                    let inRange = i >= lower && i <= upper
                    Circle().fill(inRange ? Theme.accent : Theme.rule).frame(width: 8, height: 8).position(x: x(i), y: 16)
                    Text(levels[i]).font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(inRange ? Theme.ink : Theme.ink2)
                        .position(x: x(i), y: 46)
                }
                thumb(at: x(lower), label: "Lowest level", value: levels[safe: lower]) { d in onChange(min(max(lower + d, 0), upper), upper) }
                    .zIndex(active == .lower ? 3 : 2)
                thumb(at: x(upper), label: "Highest level", value: levels[safe: upper]) { d in onChange(lower, max(min(upper + d, levels.count - 1), lower)) }
                    .zIndex(active == .upper ? 3 : 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if active == nil {
                            if lower == upper && v.translation.width == 0 { return }
                            active = pick(touch: v.startLocation.x, dx: v.translation.width, lowerX: x(lower), upperX: x(upper))
                        }
                        move(to: v.location.x, step: step)
                    }
                    .onEnded { v in
                        if active == nil {
                            active = pick(touch: v.location.x, dx: v.translation.width, lowerX: x(lower), upperX: x(upper))
                            move(to: v.location.x, step: step)
                        }
                        active = nil
                    }
            )
        }
        .frame(height: 60)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Level range")
    }

    private func thumb(at x: CGFloat, label: String, value: String?, adjust: @escaping (Int) -> Void) -> some View {
        Circle().fill(Theme.surface).frame(width: 28, height: 28)
            .overlay(Circle().stroke(Theme.accent, lineWidth: 3))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .position(x: x, y: 16)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: adjust(1)
                case .decrement: adjust(-1)
                @unknown default: break
                }
            }
    }

    private func pick(touch: CGFloat, dx: CGFloat, lowerX: CGFloat, upperX: CGFloat) -> Thumb {
        if lower == upper { return dx < 0 ? .lower : (dx > 0 ? .upper : (touch < lowerX ? .lower : .upper)) }
        return abs(touch - lowerX) <= abs(touch - upperX) ? .lower : .upper
    }

    private func move(to x: CGFloat, step: CGFloat) {
        let i = min(max(Int(((x - inset) / step).rounded()), 0), levels.count - 1)
        switch active {
        case .lower: if min(i, upper) != lower { onChange(min(i, upper), upper) }
        case .upper: if max(i, lower) != upper { onChange(lower, max(i, lower)) }
        case nil: break
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
