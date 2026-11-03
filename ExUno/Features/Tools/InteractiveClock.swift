import SwiftUI

/// A relative rotary dial: a full turn advances one hour, regardless of where a drag starts.
struct ClockRotation {
    private var previousAngle: Double?
    private var minutes: Double

    init(hour: Int, minute: Int) {
        minutes = Double(hour * 60 + minute)
    }

    static func nearestAngle(_ target: Double, to current: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return current + delta
    }

    mutating func move(to point: CGPoint, in size: CGSize) -> (hour: Int, minute: Int)? {
        guard size.width > 0, size.height > 0 else { return nil }
        let dx = Double(point.x - size.width / 2)
        let dy = Double(point.y - size.height / 2)
        // Crossing the pivot must not turn a tiny movement into a half-hour jump.
        guard hypot(dx, dy) > Double(min(size.width, size.height)) * 0.14 else {
            previousAngle = nil
            return nil
        }
        let angle = atan2(dx, -dy)
        if let previousAngle {
            var delta = angle - previousAngle
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            minutes += delta * 60 / (2 * .pi)
        }
        previousAngle = angle
        let total = (Int(minutes.rounded()) % 1440 + 1440) % 1440
        return (total / 60, total % 60)
    }
}

struct InteractiveClock: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onEditingStarted: () -> Void
    @State private var rotation: ClockRotation?
    @State private var hourAngle = 0.0
    @State private var minuteAngle = 0.0
    @State private var hasAngles = false

    var body: some View {
        GeometryReader { geometry in
            ClockFace(hourAngle: hourAngle, minuteAngle: minuteAngle)
                .contentShape(Circle())
                .highPriorityGesture(DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        var dial = rotation ?? ClockRotation(hour: hour, minute: minute)
                        if rotation == nil {
                            _ = dial.move(to: value.startLocation, in: geometry.size)
                            onEditingStarted()
                        }
                        if let time = dial.move(to: value.location, in: geometry.size) {
                            if hour != time.hour { hour = time.hour }
                            if minute != time.minute { minute = time.minute }
                        }
                        rotation = dial
                    }
                    .onEnded { _ in rotation = nil })
                .accessibilityLabel("Clock dial")
                .accessibilityValue(String(format: "%02d:%02d", hour, minute))
                .accessibilityHint("Adjusts the time one minute at a time.")
                .accessibilityAdjustableAction { direction in
                    onEditingStarted()
                    let step = direction == .increment ? 1 : -1
                    let total = (hour * 60 + minute + step + 1440) % 1440
                    hour = total / 60
                    minute = total % 60
                }
        }
        .onChange(of: hour * 60 + minute, initial: true) { _, _ in
            let targetHour = (Double(hour % 12) + Double(minute) / 60) * .pi / 6
            let targetMinute = Double(minute) * .pi / 30
            let animate = hasAngles && rotation == nil
            withAnimation(animate ? .easeInOut(duration: 0.28) : nil) {
                hourAngle = ClockRotation.nearestAngle(targetHour, to: hourAngle)
                minuteAngle = ClockRotation.nearestAngle(targetMinute, to: minuteAngle)
            }
            hasAngles = true
        }
    }
}
