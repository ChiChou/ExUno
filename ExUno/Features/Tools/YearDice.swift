import SwiftUI

/// An unmarked die: the surprise is the year it lands on.
struct YearDice: View {
    var onRoll: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lift = 0.0
    @State private var spin = 0.0
    @State private var drift = 0.0
    @State private var rolling = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Color.clear
        .frame(width: 52, height: 52)
        .overlay(alignment: .center) {
            Ellipse().fill(Theme.ink.opacity(0.12))
                .frame(width: 24, height: 5)
                .scaleEffect(max(0.3, 1 + lift / 240))
                .opacity(max(0.2, 1 + lift / 240))
                .offset(y: 19)
                .allowsHitTesting(false)
        }
        // The flight is an unclipped overlay; it does not reserve page space.
        .overlay {
            BlankCube(turn: spin)
                .frame(width: 46, height: 46)
                .scaleEffect(1 - lift / 600)
                .offset(x: drift, y: lift)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !rolling else { return }
                lift = reduceMotion ? 0 : max(-90, min(12, value.translation.height * 0.7))
                drift = reduceMotion ? 0 : max(-45, min(15, value.translation.width * 0.5))
            }
            .onEnded { value in
                guard !rolling else { return }
                if value.translation.height < -15 && value.velocity.height < -250 {
                    roll()
                } else {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { lift = 0; drift = 0 }
                }
            })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roll a year")
        .accessibilityHint("Flick the die upward to choose a random year.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { roll() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancel() } }
        .onDisappear(perform: cancel)
    }

    private func roll() {
        guard !rolling else { return }
        rolling = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        TouchFeedback.flip()
        animationTask = Task { @MainActor in
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.24)) { lift = -190; drift = -45; spin += 400 }
                do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
                withAnimation(.easeIn(duration: 0.24)) { lift = 0; drift = 0; spin += 320 }
                do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            onRoll()
            TouchFeedback.land()
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.09)) { lift = -10 }
                do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
                withAnimation(.easeIn(duration: 0.12)) { lift = 0 }
                do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            // Equivalent orientation, keeping repeated throws numerically small.
            spin = spin.truncatingRemainder(dividingBy: 360)
            rolling = false
        }
    }

    private func cancel() {
        animationTask?.cancel()
        animationTask = nil
        rolling = false
        lift = 0
        drift = 0
        spin = 0
    }
}

/// Project actual cube vertices so faces share their edges throughout a tumble.
private struct BlankCube: View, Animatable {
    var turn: Double
    var animatableData: Double {
        get { turn }
        set { turn = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let pitch = (25 + turn) * .pi / 180
            let yaw = (35 + turn) * .pi / 180
            let vertices: [(Double, Double, Double)] = [
                (-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)
            ].map { x, y, z in
                let py = y * cos(pitch) - z * sin(pitch)
                let pz = y * sin(pitch) + z * cos(pitch)
                return (x * cos(yaw) + pz * sin(yaw), py, -x * sin(yaw) + pz * cos(yaw))
            }
            let faces = [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
                         [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]
                .sorted { a, b in
                    a.reduce(0.0) { $0 + vertices[$1].2 } < b.reduce(0.0) { $0 + vertices[$1].2 }
                }
            for face in faces {
                var path = Path()
                for (index, vertex) in face.enumerated() {
                    let (x, y, z) = vertices[vertex]
                    let scale = min(size.width, size.height) * 0.29 * 6 / (6 - z)
                    let point = CGPoint(x: size.width / 2 + x * scale, y: size.height / 2 + y * scale)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                let depth = face.reduce(0.0) { $0 + vertices[$1].2 } / 4
                context.fill(path, with: .color(Theme.surface))
                context.fill(path, with: .color(Theme.ink.opacity(0.04 + (1 - depth) * 0.045)))
                context.stroke(path, with: .color(Theme.ink.opacity(0.22)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            }
        }
    }
}
