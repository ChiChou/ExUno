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

/// Units grouped by level, with overall progress on top and the conjugator as a quiet reference row.
struct GrammarCourseView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(GrammarCourses.self) private var courses

    var body: some View {
        let g = GrammarStrings.for(progress.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(g.grammar).font(Theme.display(34))
                    if let course = courses.current {
                        let passed = course.units.filter { progress.lessonScore($0.id).passed }.count
                        HStack(spacing: 10) {
                            ProgressView(value: Double(passed), total: Double(max(1, course.units.count))).tint(Theme.accent)
                            Text(g.lessons(passed, course.units.count)).font(.footnote).foregroundStyle(Theme.ink2).fixedSize()
                        }
                    }
                }
                NavigationLink(value: GrammarRoute.verbs) { ReferenceRow(icon: ToolKind.verbs.icon, title: progress.engine.title(.verbs)) }
                    .buttonStyle(.plain)
                if let course = courses.current {
                    ForEach(course.levels, id: \.self) { level in
                        let units = course.units.filter { $0.level == level }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Eyebrow(text: level)
                                Spacer()
                                Text("\(units.filter { progress.lessonScore($0.id).passed }.count)/\(units.count)").font(.caption.monospacedDigit()).foregroundStyle(Theme.ink2)
                            }
                            .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(units) { unit in
                                    let number = (course.units.firstIndex(of: unit) ?? 0) + 1
                                    NavigationLink(value: GrammarRoute.unit(unit.id)) { UnitRow(unit: unit, number: number, score: progress.lessonScore(unit.id)) }
                                        .buttonStyle(.plain)
                                    if unit != units.last { Divider().padding(.leading, 56) }
                                }
                            }
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                        }
                    }
                    Text(course.attribution).font(.caption2).foregroundStyle(Theme.ink2.opacity(0.8)).padding(.horizontal, 4)
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

/// A plain row for reference material: tinted icon, title, chevron.
private struct ReferenceRow: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent).frame(width: 28)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.rule, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// Lesson number (or a check / best-score ring), title and English gloss.
private struct UnitRow: View {
    let unit: GrammarUnit
    let number: Int
    let score: LessonScore
    var body: some View {
        HStack(spacing: 14) {
            UnitMarker(number: number, score: score)
            VStack(alignment: .leading, spacing: 1) {
                Text(unit.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(unit.en).font(.footnote).foregroundStyle(Theme.ink2).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2.opacity(0.7))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct UnitMarker: View {
    let number: Int
    let score: LessonScore
    var body: some View {
        ZStack {
            if score.passed {
                Circle().fill(Theme.greenSoft)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
            } else {
                Circle().fill(Theme.surface2)
                if score.runs > 0 {
                    Circle().trim(from: 0, to: Double(score.best) / Double(GrammarRound.size))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
                }
                Text("\(number)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink2)
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityLabel(score.passed ? "Passed" : score.runs > 0 ? "Best \(score.best) of \(GrammarRound.size)" : "Lesson \(number)")
    }
}

/// The rule and its table, with Practice pinned at the bottom; the round replaces them while it runs.
struct GrammarUnitView: View {
    @Environment(StudyProgress.self) private var progress
    let unit: GrammarUnit
    @State private var round: GrammarRound?

    var body: some View {
        let g = GrammarStrings.for(progress.language)
        let score = progress.lessonScore(unit.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Tag(text: unit.level, style: .level)
                        if score.passed { Tag(text: g.passed, style: .pos) }
                        else if score.runs > 0 { Text("\(score.best)/\(GrammarRound.size)").font(.caption.monospacedDigit()).foregroundStyle(Theme.ink2) }
                    }
                    Text(unit.title).font(Theme.display(round == nil ? 28 : 22)).foregroundStyle(Theme.ink)
                    if round == nil { Text(unit.en).font(.subheadline).foregroundStyle(Theme.ink2) }
                }
                if let round {
                    GrammarPractice(unit: unit, round: Binding(get: { round }, set: { self.round = $0 }), restart: start)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: g.rule)
                        Text(unit.note).font(.callout).lineSpacing(4).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if let table = unit.table { GrammarTableView(table: table) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            if round == nil {
                Button(g.practice, action: start).buttonStyle(Pill(style: .primary)).disabled(unit.items.isEmpty)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.bg.opacity(0.94))
            }
        }
        .pageBackground()
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

/// A paradigm table: header row, ruled rows, labels in the first column. Scrolls sideways when wide.
struct GrammarTableView: View {
    let table: GrammarTable
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(table.cols.enumerated()), id: \.offset) { _, c in
                        Text(c).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink2).fixedSize()
                    }
                }
                .padding(.bottom, 8)
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    Divider().gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { i, cell in
                            Text(cell)
                                .font(i == 0 ? .footnote : .system(size: 15, weight: .medium))
                                .foregroundStyle(i == 0 ? Theme.ink2 : Theme.ink)
                                .fixedSize()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(14)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.rule, lineWidth: 1))
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ProgressView(value: Double(round.index + (round.answered ? 1 : 0)), total: Double(round.items.count)).tint(Theme.accent)
                    Text("\(round.index + 1)/\(round.items.count)").font(.caption.monospacedDigit()).foregroundStyle(Theme.ink2)
                }
                Card(padding: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let h = item.h { Tag(text: h, style: .pos) }
                        sentence(item).font(Theme.display(22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(item.e).font(.subheadline).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
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
                    .padding(.horizontal, 4)
                    Button(round.index + 1 >= round.items.count ? s.finish : s.next) { next() }.buttonStyle(Pill(style: .primary))
                }
            }
        } else {
            let score = progress.lessonScore(unit.id)
            Card(padding: 24) {
                VStack(spacing: 12) {
                    Eyebrow(text: s.done)
                    Text("\(round.correct)/\(round.items.count)").font(Theme.display(44))
                    if score.passed { Tag(text: g.passed, style: .pos) }
                    Button(g.again, action: restart).buttonStyle(Pill(style: .primary)).padding(.top, 6)
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
