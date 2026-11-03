import SwiftUI

enum RecallSwipe: Equatable {
    case moveOn, repeatSoon

    static func action(translation: CGSize, predicted: CGSize) -> Self? {
        let x = abs(translation.width), y = translation.height
        if y > 90 && y > x * 1.15 { return .repeatSoon }
        if x > abs(y), x > 85 || (x > 35 && abs(predicted.width) > 180) { return .moveOn }
        return nil
    }
}

/// The two faces trade visibility halfway through the turn, so the answer never mirrors.
struct RecallFlip<Front: View, Back: View>: View {
    let revealed: Bool
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let angle = revealed ? 180.0 : 0
        ZStack {
            front()
                .modifier(FlipFace(angle: angle, back: false))
                .allowsHitTesting(!revealed)
                .accessibilityHidden(revealed)
            back()
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .modifier(FlipFace(angle: angle, back: true))
                .allowsHitTesting(revealed)
                .accessibilityHidden(!revealed)
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (x: 0, y: 1, z: 0))
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.32), value: revealed)
    }
}

private struct FlipFace: AnimatableModifier {
    var angle: Double
    let back: Bool
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View { content.opacity((angle >= 90) == back ? 1 : 0) }
}
