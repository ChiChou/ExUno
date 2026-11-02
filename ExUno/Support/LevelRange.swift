import SwiftUI

extension StudyProgress {
    /// The learner's level range for the current language. Cards, the widget, Words and Grammar all follow it.
    func levels(in vocab: Vocabulary) -> [String] {
        settings.levels.isEmpty ? (vocab.current?.defaultLevels ?? []) : settings.levels
    }
}

/// The one control for the level range, wherever it appears: an eyebrow and the two-thumb slider.
struct LevelRangeControl: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab

    var body: some View {
        let all = vocab.levels
        let idx = progress.levels(in: vocab).compactMap { all.firstIndex(of: $0) }
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: progress.strings.levels)
            LevelRangeSlider(levels: all, lower: idx.min() ?? 0, upper: idx.max() ?? 0) { lo, hi in
                let next = Array(all[lo...hi])
                if next != progress.settings.levels { progress.settings.levels = next }
            }
        }
    }
}

/// A compact capsule naming the current range ("A1–A2"); tapping it opens the range control in a sheet.
struct LevelRangeButton: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    @State private var open = false

    var body: some View {
        let levels = progress.levels(in: vocab)
        let label = levels.count > 1 ? "\(levels.first ?? "")–\(levels.last ?? "")" : (levels.first ?? "")
        Button { open = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13, weight: .semibold))
                Text(label).font(.subheadline.weight(.semibold).monospaced())
            }
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(Theme.surface2, in: Capsule())
            .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(progress.strings.levels)
        .accessibilityValue(label)
        .sheet(isPresented: $open) {
            LevelRangeControl().padding(20).presentationDetents([.height(150)]).presentationBackground(Theme.bg)
        }
    }
}
