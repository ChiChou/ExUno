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

/// Five daily questions, mixing bundled vocabulary, grammar and listening.
struct DailyChallengeView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    @Environment(GrammarCourses.self) private var courses
    @Environment(Speech.self) private var speech
    @State private var input = ""
    @State private var showText = false

    private var items: [DrillItem] { progress.engine.dailyChallenge(day: StudyProgress.today()) }
    private var state: Challenge {
        let d = StudyProgress.today()
        return progress.pack.challenge.day == d ? progress.pack.challenge : Challenge(day: d)
    }
    private var ready: Bool {
        vocab.isReady && vocab.current?.code == progress.language
            && (courses.current?.code == progress.language.rawValue || courses.missing)
    }
    private var preparationKey: String {
        "\(StudyProgress.today())|\(progress.language.rawValue)|\(ready)|\(progress.levels(in: vocab).joined(separator: ","))"
    }
    private var answerKey: String { "\(StudyProgress.today())|\(progress.language.rawValue)|\(state.index)" }

    var body: some View {
        let s = progress.strings
        let st = state
        let answered = st.answerWasCorrect != nil
        Card {
            VStack(spacing: 14) {
                if st.done {
                    VStack(spacing: 8) {
                        Eyebrow(text: s.done)
                        Text(s.correctCount(st.correct, items.count)).font(Theme.display(20))
                        Hint(text: s.comeBack)
                    }.frame(maxWidth: .infinity)
                } else if st.practice == nil {
                    ProgressView(vocab.error ?? "").frame(maxWidth: .infinity).padding()
                } else {
                    let index = min(st.index, items.count - 1)
                    let choice = st.practice?[index]
                    Text("\(index + 1) / \(items.count) · \(s.correctCount(st.correct, items.count))")
                        .font(.footnote).foregroundStyle(Theme.ink2)
                    if let choice {
                        DailyChoicePrompt(question: choice, language: progress.language,
                                          revealed: answered, showText: $showText)
                        VStack(spacing: 8) {
                            ForEach(choice.options, id: \.self) { option in
                                Button { record(option, correct: option == choice.answer) } label: {
                                    HStack {
                                        Text(option).multilineTextAlignment(.leading)
                                        Spacer(minLength: 8)
                                        if answered && option == choice.answer {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                                        } else if answered && option == st.chosenAnswer {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.red)
                                        }
                                    }
                                    .font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                                    .padding(12).frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Theme.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                                        answered && option == choice.answer ? Theme.green :
                                            answered && option == st.chosenAnswer ? Theme.red : Theme.rule,
                                        lineWidth: answered && (option == choice.answer || option == st.chosenAnswer) ? 2 : 1))
                                }
                                .buttonStyle(.plain).disabled(answered)
                            }
                        }
                    } else {
                        let item = items[index]
                        DrillPrompt(item: item, header: s.listen, revealed: answered, showText: $showText)
                        AnswerField(placeholder: item.placeholder, text: $input, onSubmit: check)
                            .disabled(answered)
                    }
                    if let correct = st.answerWasCorrect {
                        Text(correct ? s.right : s.was(choice?.answer ?? items[index].answer))
                            .font(.headline).foregroundStyle(correct ? Theme.green : Theme.red)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    if answered || choice == nil {
                        Button(answered ? (index + 1 >= items.count ? s.finish : s.next) : s.check, action: check)
                            .buttonStyle(Pill(style: .primary))
                            .disabled(!answered && input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .task(id: preparationKey) { prepare() }
        .onChange(of: answerKey, initial: true) { _, _ in
            input = state.chosenAnswer ?? ""
            showText = false
            speech.stop()
        }
    }

    private func prepare() {
        guard ready, state.practice == nil, !state.done else { return }
        var st = state
        st.practice = DailyChallengeChoices.make(entries: vocab.entries, units: courses.units,
                                                levels: progress.levels(in: vocab), day: st.day,
                                                language: progress.language)
        progress.pack.challenge = st
    }

    private func record(_ answer: String, correct: Bool) {
        var st = state
        guard !st.done, st.answerWasCorrect == nil else { return }
        st.chosenAnswer = answer
        st.answerWasCorrect = correct
        if correct { st.correct += 1 }
        progress.pack.challenge = st
        TouchFeedback.land()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func check() {
        var st = state
        guard !st.done else { return }
        if st.answerWasCorrect != nil {
            st.index += 1
            st.done = st.index >= items.count
            st.chosenAnswer = nil
            st.answerWasCorrect = nil
            progress.pack.challenge = st
            input = ""; showText = false
            speech.stop()
            return
        }
        guard st.practice?[st.index] == nil else { return }
        let item = items[min(st.index, items.count - 1)]
        record(input, correct: item.check(input))
    }
}

private struct DailyChoicePrompt: View {
    let question: DailyChoiceQuestion
    let language: LanguageCode
    let revealed: Bool
    @Binding var showText: Bool

    var body: some View {
        VStack(spacing: 12) {
            Eyebrow(text: instruction)
            if question.kind == .listening {
                HStack {
                    SpeakButton(text: question.spoken)
                    Button { showText.toggle() } label: {
                        Image(systemName: showText ? "eye.slash" : "eye")
                    }
                    .buttonStyle(Pill(style: .ghost, compact: true))
                    .accessibilityLabel(UIStrings.for(language).showText)
                }
                if showText || revealed { prompt(question.prompt) }
            } else {
                prompt(question.kind == .gap && revealed
                       ? question.prompt.replacingOccurrences(of: GrammarItem.gap, with: question.answer)
                       : question.prompt)
                if question.kind == .meaning || ((question.kind == .gap || question.kind == .word) && revealed) {
                    SpeakButton(text: question.spoken, small: true)
                }
            }
            if let explanation = question.explanation, question.kind == .gap || revealed {
                Text(explanation).font(.subheadline).foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(Theme.surface2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private func prompt(_ text: String) -> some View {
        Text(text).font(Theme.display(21, weight: .semibold)).multilineTextAlignment(.center)
    }

    private var instruction: String {
        let labels: [String]
        switch language {
        case .it: labels = ["Scegli il significato", "Scegli la parola", "Completa la frase", "Ascolta e scegli"]
        case .es, .esLatAm: labels = ["Elige el significado", "Elige la palabra", "Completa la frase", "Escucha y elige"]
        case .fr: labels = ["Choisis le sens", "Choisis le mot", "Complète la phrase", "Écoute et choisis"]
        case .pt: labels = ["Escolhe o significado", "Escolhe a palavra", "Completa a frase", "Ouve e escolhe"]
        case .ptBR: labels = ["Escolha o significado", "Escolha a palavra", "Complete a frase", "Ouça e escolha"]
        case .la: labels = ["Significātiōnem ēlige", "Verbum ēlige", "Sententiam complē", "Audī et ēlige"]
        }
        switch question.kind {
        case .meaning: return labels[0]
        case .word: return labels[1]
        case .gap: return labels[2]
        case .listening: return labels[3]
        }
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
