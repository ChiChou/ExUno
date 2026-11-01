import SwiftUI

/// Where the Grammar tab can navigate: a unit, or the verb conjugator (moved here from Tools).
enum GrammarRoute: Hashable {
    case unit(String)
    case verbs
}

/// The Grammar tab: the course by level, with the conjugator as a reference at the top.
struct GrammarTab: View {
    @Environment(GrammarCourses.self) private var courses
    @Environment(Router.self) private var router
    @State private var path: [GrammarRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            GrammarCourseView()
                .navigationDestination(for: GrammarRoute.self) { route in
                    switch route {
                    case .verbs: ToolPage(tool: .verbs)
                    case .unit(let id):
                        if let unit = courses.units.first(where: { $0.id == id }) { GrammarUnitView(unit: unit) }
                    }
                }
        }
        .onAppear { consumeRoute() }
        .onChange(of: router.grammar) { _, _ in consumeRoute() }
    }

    private func consumeRoute() {
        guard let r = router.grammar else { return }
        router.grammar = nil
        path = [r]
    }
}

/// Units grouped by level.
struct GrammarCourseView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(GrammarCourses.self) private var courses

    var body: some View {
        let g = GrammarStrings.for(progress.language)
        let engine = progress.engine
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.grammar).font(Theme.display(34))
                    if let course = courses.current {
                        Hint(text: g.lessons(course.units.filter { progress.lessonScore($0.id).passed }.count, course.units.count))
                    }
                }
                NavigationLink(value: GrammarRoute.verbs) { ToolRow(tool: .verbs, title: engine.title(.verbs)) }
                    .buttonStyle(.plain)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                if let course = courses.current {
                    ForEach(course.levels, id: \.self) { level in
                        let units = course.units.filter { $0.level == level }
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: level)
                            VStack(spacing: 0) {
                                ForEach(units) { unit in
                                    NavigationLink(value: GrammarRoute.unit(unit.id)) { UnitRow(unit: unit, score: progress.lessonScore(unit.id)) }
                                        .buttonStyle(.plain)
                                    if unit != units.last { Divider().padding(.leading, 14) }
                                }
                            }
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                        }
                    }
                    Hint(text: course.attribution)
                } else if courses.missing {
                    ErrorReadout(message: "The \(progress.language.englishName) grammar course isn't installed. Build it with sh Scripts/prepare_data.sh, or download it with sh Scripts/download_packs.sh.")
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct UnitRow: View {
    let unit: GrammarUnit
    let score: LessonScore
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(unit.en).font(.footnote).foregroundStyle(Theme.ink2)
            }
            Spacer()
            if score.passed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).accessibilityLabel("Passed")
            } else if score.runs > 0 {
                Text("\(score.best)/\(GrammarRound.size)").font(Theme.mono(13)).foregroundStyle(Theme.ink2)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

/// The rule, its table, and a practice round.
struct GrammarUnitView: View {
    @Environment(StudyProgress.self) private var progress
    let unit: GrammarUnit
    @State private var round: GrammarRound?

    var body: some View {
        let g = GrammarStrings.for(progress.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Tag(text: unit.level, style: .level)
                    Text(unit.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                    Text(unit.en).font(.subheadline).foregroundStyle(Theme.ink2)
                }
                if let round {
                    GrammarPractice(unit: unit, round: Binding(get: { round }, set: { self.round = $0 }), restart: start)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: g.rule)
                            Text(unit.note).font(.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let table = unit.table { GrammarTableView(table: table) }
                    Button(g.practice, action: start).buttonStyle(Pill(style: .primary)).disabled(unit.items.isEmpty)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .pageBackground()
        .navigationTitle(GrammarStrings.for(progress.language).grammar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if round != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { round = nil } label: { Image(systemName: "book") }.accessibilityLabel(g.rule)
                }
            }
        }
    }

    private func start() { round = GrammarRound(unit: unit, run: progress.lessonScore(unit.id).runs) }
}

struct GrammarTableView: View {
    let table: GrammarTable
    var body: some View {
        Card(padding: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        ForEach(Array(table.cols.enumerated()), id: \.offset) { _, c in
                            Text(c).font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
                        }
                    }
                    Divider()
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { i, cell in
                                Text(cell)
                                    .font(i == 0 ? .footnote : .system(size: 15, weight: .semibold))
                                    .foregroundStyle(i == 0 ? Theme.ink2 : Theme.ink)
                                    .fixedSize()
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Multiple-choice cloze: pick the form that fits the gap.
struct GrammarPractice: View {
    @Environment(StudyProgress.self) private var progress
    let unit: GrammarUnit
    @Binding var round: GrammarRound
    let restart: () -> Void

    var body: some View {
        let s = progress.strings
        let g = GrammarStrings.for(progress.language)
        if let item = round.current {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("\(round.index + 1) / \(round.items.count) · \(s.correctCount(round.correct, round.items.count))").font(.footnote).foregroundStyle(Theme.ink2)
                        Spacer()
                        if let h = item.h { Tag(text: h, style: .pos) }
                    }
                    sentence(item).font(Theme.display(22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(item.e).font(.subheadline).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(item.o, id: \.self) { option in
                            // Repeat taps are ignored by GrammarRound.choose; disabling hit-testing mid-tap kept the pill from restyling.
                            Button(option) { answer(option) }
                                .buttonStyle(Pill(style: style(for: option, item: item)))
                        }
                    }
                    if round.answered {
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(round.wasCorrect ? s.right : s.was(item.a)).font(.headline).foregroundStyle(round.wasCorrect ? Theme.green : Theme.red)
                                Text(item.g).font(.footnote).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            SpeakButton(text: item.sentence, small: true)
                        }
                        Button(round.index + 1 >= round.items.count ? s.finish : s.next) { next() }.buttonStyle(Pill(style: .primary))
                    }
                }
            }
        } else {
            let score = progress.lessonScore(unit.id)
            Card {
                VStack(spacing: 10) {
                    Eyebrow(text: s.done)
                    Text(s.correctCount(round.correct, round.items.count)).font(Theme.display(24))
                    if score.passed { Tag(text: g.passed, style: .pos) }
                    Button(g.again, action: restart).buttonStyle(Pill(style: .primary))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sentence(_ item: GrammarItem) -> Text {
        let gap = round.answered ? Text(item.a).foregroundStyle(round.wasCorrect ? Theme.green : Theme.red).underline() : Text("____").foregroundStyle(Theme.accent)
        return Text(item.before).foregroundStyle(Theme.ink) + gap + Text(item.after).foregroundStyle(Theme.ink)
    }

    private func style(for option: String, item: GrammarItem) -> PillStyle {
        guard let chosen = round.chosen else { return .neutral }
        if option == item.a { return .good }
        return option == chosen ? .bad : .ghost
    }

    private func answer(_ option: String) {
        let correct = round.choose(option)
        progress.logGrammarAnswer(correct: correct)
    }

    private func next() {
        round.advance()
        if round.isFinished { progress.finishLesson(unit.id, correct: round.correct) }
    }
}
