import CoreMotion
import SwiftUI
import UIKit

/// One sensor stream for the app, running only while a visible interaction needs it.
@MainActor @Observable
final class MotionFeedback {
    static let shared = MotionFeedback()
    private(set) var roll = 0.0
    private(set) var pitch = 0.0
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var clients = Set<UUID>()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var origin: (roll: Double, pitch: Double)?
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func acquire(_ client: UUID) {
        clients.insert(client)
        guard task == nil, isAvailable else { return }
        origin = nil
        roll = 0; pitch = 0
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                do { try await Task.sleep(for: .milliseconds(33)) }
                catch { return }
            }
        }
    }

    func release(_ client: UUID) {
        clients.remove(client)
        guard clients.isEmpty else { return }
        task?.cancel(); task = nil
        manager.stopDeviceMotionUpdates()
        origin = nil
        roll = 0; pitch = 0
    }

    private func sample() {
        guard let gravity = manager.deviceMotion?.gravity else { return }
        // Gravity gives a stable, intuitive left/right tilt with a portrait phone.
        // Attitude Euler angles become unstable near the upright reading position.
        guard hypot(gravity.x, gravity.y) > 0.15 else {
            origin = nil; roll = 0; pitch = 0
            return
        }
        let currentRoll = atan2(gravity.x, -gravity.y)
        let currentPitch = atan2(gravity.z, hypot(gravity.x, gravity.y))
        if origin == nil { origin = (currentRoll, currentPitch) }
        guard let origin else { return }
        roll += (Self.relativeAngle(currentRoll, origin.roll) - roll) * 0.18
        pitch += (Self.relativeAngle(currentPitch, origin.pitch) - pitch) * 0.18
    }

    nonisolated static func relativeAngle(_ angle: Double, _ origin: Double) -> Double {
        atan2(sin(angle - origin), cos(angle - origin))
    }
}

/// Device movement affects the card's appearance; study actions remain deliberate.
private struct CardMotion: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let motion = MotionFeedback.shared
    func body(content: Content) -> some View {
        let x = active ? min(1, max(-1, motion.roll / 0.35)) : 0
        let y = active ? min(1, max(-1, motion.pitch / 0.35)) : 0
        content
            .rotation3DEffect(.degrees(-y * 4), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
            .rotation3DEffect(.degrees(x * 5), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .offset(x: x * 3, y: y * 2)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: active)
    }
}

extension View {
    func motionCard(active: Bool) -> some View { modifier(CardMotion(active: active)) }
}

/// Short system feedback, with a rate limit for moving dials.
@MainActor
enum TouchFeedback {
    private static let selection = UISelectionFeedbackGenerator()
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static var lastTick = -Double.infinity
    private static var lastImpact = -Double.infinity

    static func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTick >= 0.09 else { return }
        lastTick = now
        selection.selectionChanged()
    }
    static func flip() { soft.impactOccurred(intensity: 0.55) }
    static func land() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastImpact >= 0.12 else { return }
        lastImpact = now
        light.impactOccurred(intensity: 0.7)
    }
}
