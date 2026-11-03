import Combine
import SwiftUI

struct TodayView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    @Environment(Router.self) private var router
    @Environment(GrammarCourses.self) private var courses
    @State private var now = Date()
    @State private var showLanguages = false
    @State private var showSettings = false
    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = progress.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text(s.greeting(hour: Calendar.current.component(.hour, from: now))).font(Theme.display(34)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { showLanguages = true } label: {
                        Text(progress.language.badge)
                            .font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(1)
                            .foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 32)
                            .background(Theme.surface2, in: Capsule())
                            .overlay(Capsule().stroke(Theme.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Language: \(progress.language.englishName)")
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 32, height: 32)
                            .background(Theme.surface2, in: Circle())
                            .overlay(Circle().stroke(Theme.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                LiveClock(now: now)
                sessionCard(s)
                grammarCard()
                Text(s.dailyChallenge).font(Theme.display(21))
                DailyChallengeView()
                progressSection(s)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(timer) { now = $0 }
        .sheet(isPresented: $showLanguages) { LanguagePicker() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// The next grammar unit not yet passed, in course order.
    @ViewBuilder
    private func grammarCard() -> some View {
        if let course = courses.current, !course.units.isEmpty {
            let g = GrammarStrings.for(progress.language)
            let passed = course.units.filter { progress.lessonScore($0.id).passed }.count
            let next = course.units.first { !progress.lessonScore($0.id).passed }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Eyebrow(text: g.grammar)
                        Spacer()
                        Hint(text: g.lessons(passed, course.units.count))
                    }
                    if let next {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(next.title).font(Theme.display(20)).foregroundStyle(Theme.ink)
                            Tag(text: next.level, style: .level)
                        }
                        Text(next.en).font(.footnote).foregroundStyle(Theme.ink2)
                        Button(progress.lessonScore(next.id).runs > 0 ? progress.strings.keepGoing : g.practice) { router.openGrammar(.unit(next.id)) }
                            .buttonStyle(Pill(style: .neutral))
                    } else {
                        Text(g.passed).font(Theme.display(20)).foregroundStyle(Theme.ink)
                        Button(g.course) { router.tab = .grammar }.buttonStyle(Pill(style: .neutral))
                    }
                }
            }
        }
    }

    /// Streak, deck size and the last two weeks, in one place.
    private func progressSection(_ s: UIStrings) -> some View {
        let total = progress.pack.log.values.reduce(0) { $0 + $1.reviews }
        let good = progress.pack.log.values.reduce(0) { $0 + $1.good }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatTile(value: "\(progress.streak)", label: s.streak)
                StatTile(value: "\(progress.pack.cards.count)", label: s.seen)
                StatTile(value: "\(progress.pack.cards.values.filter { $0.interval >= 7 }.count)", label: s.solid)
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("14").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
                        Spacer()
                        Hint(text: total > 0 ? "\(total) \(s.cards.lowercased()) · \(Int((Double(good) / Double(total) * 100).rounded()))% \(s.good.lowercased())" : "–")
                    }
                    HistoryChart(log: progress.pack.log)
                }
            }
        }
    }

    private func sessionCard(_ s: UIStrings) -> some View {
        let due = progress.dueCardIDs().count
        let log = progress.todayLog()
        let goal = progress.app.goal
        return Card {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: s.reviewToday)
                    Text(due > 0 ? s.due(due) : log.reviews >= goal ? s.goalReached : s.readyForNew)
                        .font(Theme.display(20)).foregroundStyle(Theme.ink)
                    Text(s.cardsToday(log.reviews, goal)).font(.footnote).foregroundStyle(Theme.ink2)
                    Button(log.reviews > 0 ? s.keepGoing : s.start) { router.tab = .cards }
                        .buttonStyle(Pill(style: .primary))
                        .disabled(!vocab.isReady)
                }
                GoalRing(value: log.reviews, goal: goal)
            }
        }
    }
}

/// Switch the study language on the fly; each keeps its own progress.
struct LanguagePicker: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 580

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Language").font(Theme.display(24)).padding(.bottom, 4)
                ForEach(LanguageCode.alphabetical) { code in
                    Button {
                        if code != progress.language { progress.switchTo(code) }
                        dismiss()
                    } label: { LanguageRow(code: code, selected: code == progress.language, compact: true) }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height.rounded(.up)
            } action: { height in
                if height > 0 { contentHeight = height }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .pageBackground()
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }
}

struct LiveClock: View {
    @Environment(StudyProgress.self) private var progress
    let now: Date
    var body: some View {
        let card = progress.engine.clockCard(now)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: card.question, color: Theme.onSlab.opacity(0.65))
                Spacer()
                SpeakButton(text: "\(card.headline). \(card.line).", onDark: true)
            }
            Text(card.headline).font(Theme.display(26)).foregroundStyle(Theme.onSlab).fixedSize(horizontal: false, vertical: true)
            Text(card.line).font(Theme.display(16, weight: .medium)).foregroundStyle(Theme.onSlab.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            Text(now.formatted(date: .numeric, time: .shortened)).font(Theme.mono(13)).foregroundStyle(Theme.onSlab.opacity(0.65))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.slab, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct GoalRing: View {
    let value: Int
    let goal: Int
    var body: some View {
        let pct = min(1, Double(value) / Double(max(1, goal)))
        ZStack {
            Circle().stroke(Theme.surface2, lineWidth: 7)
            Circle().trim(from: 0, to: pct).stroke(Theme.amber, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(value)").font(Theme.display(20)).foregroundStyle(Theme.ink)
        }
        .frame(width: 74, height: 74)
        .animation(.easeOut(duration: 0.4), value: pct)
    }
}

/// Five items read aloud, answered with digits. Same items all day.
struct DailyChallengeView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    @State private var input = ""
    @State private var answered = false
    @State private var wasCorrect = false
    @State private var showText = false

    private var items: [DrillItem] { progress.engine.dailyChallenge(day: StudyProgress.today()) }
    private var state: Challenge {
        let d = StudyProgress.today()
        return progress.pack.challenge.day == d ? progress.pack.challenge : Challenge(day: d)
    }

    var body: some View {
        let s = progress.strings
        let st = state
        Card {
            VStack(spacing: 14) {
                if st.done {
                    VStack(spacing: 8) {
                        Eyebrow(text: s.done)
                        Text(s.correctCount(st.correct, items.count)).font(Theme.display(20))
                        Hint(text: s.comeBack)
                    }.frame(maxWidth: .infinity)
                } else {
                    let item = items[min(st.index, items.count - 1)]
                    DrillPrompt(item: item, header: "\(st.index + 1) / \(items.count) · \(s.correctCount(st.correct, items.count))", revealed: answered, showText: $showText)
                    AnswerField(placeholder: item.placeholder, text: $input, onSubmit: check)
                    if answered {
                        Text(wasCorrect ? s.right : s.was(item.answer)).font(.headline).foregroundStyle(wasCorrect ? Theme.green : Theme.red)
                    }
                    Button(answered ? (st.index + 1 >= items.count ? s.finish : s.next) : s.check, action: check).buttonStyle(Pill(style: .primary))
                }
            }
        }
    }

    private func check() {
        var st = state
        let item = items[min(st.index, items.count - 1)]
        if answered {
            st.index += 1
            if st.index >= items.count { st.done = true }
            progress.pack.challenge = st
            input = ""; answered = false; showText = false
            if !st.done { let next = items[st.index].spoken; speech.speak(next, id: "speak:" + next) }
            return
        }
        wasCorrect = item.check(input)
        if wasCorrect { st.correct += 1 }
        answered = true
        progress.pack.challenge = st
    }
}

/// The listen-first prompt shared by the daily challenge and the tool drills.
struct DrillPrompt: View {
    let item: DrillItem
    let header: String
    let revealed: Bool
    @Binding var showText: Bool
    var body: some View {
        VStack(spacing: 12) {
            Text(header).font(.footnote).foregroundStyle(Theme.ink2)
            HStack(spacing: 10) {
                SpeakButton(text: item.spoken)
                Button { showText.toggle() } label: { Image(systemName: showText ? "eye.slash" : "eye") }
                    .buttonStyle(Pill(style: .ghost, compact: true))
                    .accessibilityLabel("Show text")
            }
            Text(item.spoken).font(Theme.display(19, weight: .semibold)).multilineTextAlignment(.center)
                .blur(radius: showText || revealed ? 0 : 8)
                .animation(.easeOut(duration: 0.2), value: showText)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.surface2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AnswerField: View {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .autocorrectionDisabled().textInputAutocapitalization(.characters)
            .padding(.horizontal, 14).frame(minHeight: 50)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
            .onSubmit(onSubmit)
    }
}

struct HistoryChart: View {
    let log: [Int: DayLog]
    var body: some View {
        let today = StudyProgress.today()
        let days = (0..<14).map { today - 13 + $0 }
        let maxN = max(1, days.map { log[$0]?.reviews ?? 0 }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.self) { d in
                let n = log[d]?.reviews ?? 0
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(d == today ? Theme.amber : Theme.accent)
                        .frame(height: n > 0 ? max(4, CGFloat(n) / CGFloat(maxN) * 60) : 2)
                        .frame(maxHeight: 60, alignment: .bottom)
                    Text(dayLabel(d)).font(.system(size: 9)).foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }
    private func dayLabel(_ day: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(day) * 86_400 - Double(TimeZone.current.secondsFromGMT()) + 43_200)
        return "\(Calendar.current.component(.day, from: date))"
    }
}
