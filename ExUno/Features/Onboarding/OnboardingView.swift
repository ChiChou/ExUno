import SwiftUI

/// First run: pick a language, a starting level and a daily goal.
struct OnboardingView: View {
    @Environment(StudyProgress.self) private var progress
    @State private var step = 0
    @State private var language: LanguageCode? = nil
    @State private var level = ""
    @State private var goal = 20

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule().fill(i <= step ? Theme.accent : Theme.surface2).frame(height: 4)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: languageStep
                    case 1: levelStep
                    default: goalStep
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }.buttonStyle(Pill(style: .ghost)).frame(width: 110)
                }
                Button(step == 2 ? "Start" : "Continue") { advance() }
                    .buttonStyle(Pill(style: .primary))
                    .disabled(step == 0 && language == nil)
                    .opacity(step == 0 && language == nil ? 0.5 : 1)
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .pageBackground()
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ex Uno").font(Theme.display(44))
                Text("Out of one, many.").font(Theme.display(22, weight: .medium)).foregroundStyle(Theme.amber)
                Text("Latin gave the world Italian, Spanish, French and Portuguese. Learn them the way you meet them: on receipts, clocks, tickets and signs.")
                    .font(.title3).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            }
            Text("Which language?").font(Theme.display(21)).padding(.top, 6)
            VStack(spacing: 10) {
                ForEach(LanguageCode.alphabetical) { code in
                    Button { language = code; level = code.startLevels[0] } label: { LanguageRow(code: code, selected: language == code) }
                        .buttonStyle(.plain)
                }
            }
            Text("You can switch languages any time; each keeps its own progress.").font(.footnote).foregroundStyle(Theme.ink2)
        }
    }

    private var levelStep: some View {
        let code = language ?? .it
        return VStack(alignment: .leading, spacing: 18) {
            Text("Where do you start?").font(Theme.display(30))
            Text(code == .la ? "Latin words are ranked by how often they appear in classical texts." : "Levels follow the European CEFR scale.")
                .foregroundStyle(Theme.ink2)
            VStack(spacing: 10) {
                ForEach(code.startLevels, id: \.self) { l in
                    Button { level = l } label: {
                        HStack(spacing: 14) {
                            Text(l).font(Theme.display(20)).foregroundStyle(level == l ? Theme.onAccent : Theme.amber)
                                .frame(width: 52, height: 44)
                                .background(level == l ? Theme.accent : Theme.amberSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(levelBlurb(code, l)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                            Spacer()
                            if level == l { Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Theme.accent) }
                        }
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(level == l ? Theme.accent : Theme.rule, lineWidth: level == l ? 2 : 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How many cards a day?").font(Theme.display(30))
            Text("Real-life cards and the daily challenge come on top.").foregroundStyle(Theme.ink2)
            HStack(spacing: 10) {
                ForEach([10, 20, 30], id: \.self) { g in
                    Button { goal = g } label: {
                        VStack(spacing: 4) {
                            Text("\(g)").font(Theme.display(30))
                            Text(g == 10 ? "≈ 5 min" : g == 20 ? "≈ 10 min" : "≈ 15 min").font(.caption)
                        }
                        .foregroundStyle(goal == g ? Theme.onAccent : Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .background(goal == g ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.rule, lineWidth: goal == g ? 0 : 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func levelBlurb(_ code: LanguageCode, _ l: String) -> String {
        switch l {
        case "A1": return "Just starting"
        case "A2": return "I know the basics"
        case "B1": return "I can get by"
        case "B2": return "I'm comfortable"
        case "I": return "The 250 most common words"
        case "II": return "Words 251–500"
        case "III": return "Words 501–750"
        case "IV": return "Words 751–1000"
        default: return ""
        }
    }

    private func advance() {
        if step < 2 { withAnimation { step += 1 }; return }
        guard let code = language else { return }
        progress.switchTo(code)
        var s = progress.settings
        let all = code == .la ? ["I", "II", "III", "IV"] : ["A1", "A2", "B1", "B2", "C1", "C2"]
        if let i = all.firstIndex(of: level) { s.levels = Array(all[i...min(i + 1, all.count - 1)]) }
        if code == .la { s.levels = [level] }
        progress.settings = s
        progress.app.goal = goal
        progress.app.onboarded = true
    }
}

struct LanguageRow: View {
    let code: LanguageCode
    let selected: Bool
    var compact = false
    var body: some View {
        HStack(spacing: 14) {
            Text(code.rawValue.uppercased())
                .font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(1)
                .foregroundStyle(Theme.ink)
                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(code.nativeName).font(Theme.display(compact ? 17 : 20)).foregroundStyle(Theme.ink)
                Text(compact ? code.englishName : "\(code.hello)! · \(code.englishName)").font(.subheadline).foregroundStyle(Theme.ink2)
            }
            Spacer()
            if selected { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Theme.accent) }
        }
        .padding(compact ? 10 : 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? Theme.accent : Theme.rule, lineWidth: selected ? 2 : 1))
    }
}
