import SwiftUI

struct CardsView: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    @State private var deck = DeckEngine()
    @State private var showOptions = false
    @State private var showSummary = false
    @State private var dragOffset: CGFloat = 0
    @State private var leaving: CGFloat = 0
    @State private var cardKey = 0
    /// Per device and not synced: roaming is a way to look around, not part of study progress.
    @AppStorage("cards.roaming") private var roaming = false

    private var settings: PackSettings { progress.settings }

    var body: some View {
        let s = progress.strings
        VStack(spacing: 14) {
            topBar
            if !roaming {
                ProgressView(value: min(1, Double(progress.todayLog().reviews) / Double(max(1, progress.app.goal)))).tint(Theme.accent)
            }
            if !vocab.isReady {
                Spacer()
                if let error = vocab.error { Text(error).foregroundStyle(Theme.ink2).multilineTextAlignment(.center).padding() } else { ProgressView() }
                Spacer()
            } else if let card = deck.current {
                stage(card)
                controls(card, s)
            } else {
                Spacer()
                Text(s.nothingHere).font(Theme.display(22)).foregroundStyle(Theme.ink2)
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if vocab.isReady && (!deck.built || deck.roaming != roaming) { rebuild() } }
        .onChange(of: vocab.isReady) { _, ready in if ready && !deck.built { rebuild() } }
        .onChange(of: deck.summaryDue) { _, due in if due { deck.summaryDue = false; showSummary = true } }
        .sheet(isPresented: $showOptions, onDismiss: { if !deck.built { rebuild() } }) {
            DeckOptionsView(deck: deck).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSummary) { SessionSummaryView().presentationDetents([.medium, .large]) }
        .onDisappear { speech.stop() }
    }

    private func rebuild() {
        if roaming { deck.buildRoaming(vocab: vocab, settings: settings) } else { deck.build(vocab: vocab, progress: progress) }
        cardKey += 1
    }

    /// Flow and Recall are the synced study modes; Roam is a local, untracked browse.
    private enum ModeChoice: Hashable { case study(StudyMode), roam }

    private var topBar: some View {
        HStack {
            Picker("Mode", selection: Binding<ModeChoice>(get: { roaming ? .roam : .study(settings.mode) }, set: { choice in
                let wasRoaming = roaming
                switch choice {
                case .roam: roaming = true
                case .study(let m): roaming = false; progress.settings.mode = m
                }
                if roaming != wasRoaming { rebuild() } else { deck.revealed = false }
            })) {
                Text("Flow").tag(ModeChoice.study(.flow))
                Text("Recall").tag(ModeChoice.study(.recall))
                Text("Roam").tag(ModeChoice.roam)
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
            Spacer()
            if !roaming {
                Text("\(progress.todayLog().reviews) / \(progress.app.goal)").font(.footnote.monospacedDigit()).foregroundStyle(Theme.ink2)
            }
            Button { showOptions = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40).background(Theme.surface2, in: Circle()).foregroundStyle(Theme.ink)
            }.buttonStyle(.plain).accessibilityLabel("Deck options")
        }
    }

    private func isShown(_ card: DeckCard) -> Bool {
        switch card {
        case .word: return roaming || settings.mode == .flow || deck.revealed
        case .realia: return deck.revealed
        }
    }

    @ViewBuilder
    private func stage(_ card: DeckCard) -> some View {
        ZStack {
            switch card {
            case .word(let id, let again):
                if let e = vocab.entry(id) {
                    WordCardView(entry: e, again: again, showAnswer: isShown(card), reveal: { deck.revealed = true })
                } else {
                    Color.clear.onAppear { deck.advance(.good, vocab: vocab, progress: progress) }
                }
            case .realia(let r):
                RealiaCardView(realia: r, showAnswer: deck.revealed, reveal: { deck.revealed = true })
            }
        }
        .id(cardKey)
        .offset(x: dragOffset + leaving * 600)
        .rotationEffect(.degrees(Double(dragOffset + leaving * 600) / 30))
        .opacity(leaving == 0 ? 1 : 0)
        .animation(.spring(duration: 0.28), value: leaving)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { v in if abs(v.translation.width) > abs(v.translation.height) { dragOffset = v.translation.width } }
                .onEnded { v in
                    let dx = v.translation.width
                    if abs(dx) > 90 {
                        if case .word = card, !roaming, settings.mode == .recall, !deck.revealed { withAnimation { dragOffset = 0 }; deck.revealed = true }
                        else { leave(dx > 0 ? .good : .again) }
                    } else { withAnimation(.spring(duration: 0.25)) { dragOffset = 0 } }
                }
        )
        .onTapGesture { if !deck.revealed { deck.revealed = true } }
    }

    private func leave(_ g: Grade) {
        leaving = g == .again ? -1 : 1
        dragOffset = 0
        let generation = deck.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // The deck may have been rebuilt meanwhile (e.g. switching from Roam to Recall); a roaming tap must never grade a study card.
            if deck.generation == generation { deck.advance(g, vocab: vocab, progress: progress) }
            leaving = 0
            cardKey += 1
            speech.stop()
        }
    }

    @ViewBuilder
    private func controls(_ card: DeckCard, _ s: UIStrings) -> some View {
        HStack(spacing: 8) {
            Button { deck.back(); cardKey += 1 } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 44).foregroundStyle(Theme.ink2).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(!deck.canGoBack).opacity(deck.canGoBack ? 1 : 0.4).accessibilityLabel("Previous card")
            switch card {
            case .realia where !deck.revealed:
                Button(s.howToSay) { deck.revealed = true }.buttonStyle(Pill(style: .primary))
            case .word where roaming:
                Button { leave(.good) } label: { HStack { Text(s.next); Image(systemName: "chevron.right") } }.buttonStyle(Pill(style: .neutral))
            case .realia:
                Button(s.didntKnow) { leave(.again) }.buttonStyle(Pill(style: .bad))
                Button(s.knew) { leave(.good) }.buttonStyle(Pill(style: .good))
            case .word where settings.mode == .flow:
                Button(s.hard) { leave(.again) }.buttonStyle(Pill(style: .amber))
                Button { leave(.good) } label: { HStack { Text(s.next); Image(systemName: "chevron.right") } }.buttonStyle(Pill(style: .primary))
            case .word where !deck.revealed:
                Button(s.showAnswer) { deck.revealed = true }.buttonStyle(Pill(style: .primary))
            case .word(let id, _):
                GradeButton(title: s.again, sub: s.todayShort, color: Theme.red) { leave(.again) }
                GradeButton(title: s.good, sub: progress.nextInterval(id, .good, strings: s), color: Theme.green) { leave(.good) }
                GradeButton(title: s.easy, sub: progress.nextInterval(id, .easy, strings: s), color: Theme.accent) { leave(.easy) }
            }
        }
    }
}

/// A quiet, single-line grade choice: colored label on the card surface, interval underneath.
struct GradeButton: View {
    let title: String
    let sub: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                Text(sub).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink2)
            }
            .lineLimit(1).minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.rule, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFade())
    }
}

/// Dims a plain button while it is pressed.
struct PressFade: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1).animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Word card

struct WordCardView: View {
    @Environment(StudyProgress.self) private var progress
    let entry: Entry
    var again = false
    let showAnswer: Bool
    let reveal: () -> Void

    var body: some View {
        let s = progress.strings
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Tag(text: entry.level, style: .level)
                    if !entry.pos.isEmpty { Tag(text: entry.pos, style: .pos) }
                    if let g = entry.genderLabel { Tag(text: g, style: .gender) }
                    if again { Tag(text: s.again) }
                }
                wordLine.padding(.top, 18)
                if let f = entry.forms { Text(f).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink2).padding(.top, 4) }
                SpeakButton(text: entry.spoken).padding(.top, 12)
                if showAnswer {
                    VStack(spacing: 14) {
                        Text(entry.translation).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.green).multilineTextAlignment(.center)
                        if !entry.exampleNative.isEmpty {
                            Divider()
                            HStack(spacing: 6) {
                                Text(entry.exampleNative).font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.center)
                                SpeakButton(text: entry.exampleNative, small: true)
                            }
                            Text(entry.exampleEnglish).font(.subheadline).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                        }
                        if entry.pos == "verb", let cj = progress.engine.conjugate(entry.word, hint: entry.verbHint), let t = cj.tenses.first {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "\(t.name) · \(t.note)")
                                ConjugationGrid(forms: t.forms, pronouns: cj.pronouns)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 18)
                } else {
                    Button(s.show, action: reveal).buttonStyle(Pill(style: .ghost, compact: true)).padding(.top, 36)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.rule, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.10), radius: 20, y: 10)
    }

    private var wordLine: some View {
        let article = entry.article
        return (Text(article.isEmpty ? "" : (article.hasSuffix("'") ? article : article + " ")).foregroundStyle(Theme.ink2).fontWeight(.medium)
                + Text(entry.word).foregroundStyle(Theme.ink))
            .font(Theme.display(entry.isPhrase ? 26 : 40, weight: entry.isPhrase ? .semibold : .bold))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .textSelection(.enabled)
    }
}

struct ConjugationGrid: View {
    let forms: [String]
    var pronouns: [String] = []
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 4) {
            ForEach(Array(forms.enumerated()), id: \.offset) { i, f in
                HStack(spacing: 6) {
                    if i < pronouns.count { Text(pronouns[i]).foregroundStyle(Theme.ink2).frame(width: 52, alignment: .leading) }
                    Text(f).fontWeight(.semibold)
                }.font(.subheadline)
            }
        }
    }
}

// MARK: - Session summary

struct SessionSummaryView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let s = progress.strings
        let log = progress.todayLog()
        let today = StudyProgress.today()
        let missed = progress.pack.cards.filter { $0.value.lastSeen == today && $0.value.interval == 0 }.keys.compactMap { vocab.entry($0) }.prefix(8)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: s.session)
                Text(s.cardsToday(log.reviews, progress.app.goal)).font(Theme.display(24))
                HStack(spacing: 8) {
                    StatTile(value: "\(log.good)", label: s.good); StatTile(value: "\(log.again)", label: s.hard); StatTile(value: "\(log.new)", label: "+")
                }
                if !missed.isEmpty {
                    Eyebrow(text: s.toReview)
                    VStack(spacing: 0) {
                        ForEach(Array(missed)) { e in
                            HStack {
                                VStack(alignment: .leading) { Text(e.wordWithArticle).fontWeight(.semibold); Text(e.translation).font(.subheadline).foregroundStyle(Theme.ink2).lineLimit(1) }
                                Spacer()
                                SpeakButton(text: e.spoken, small: true)
                            }.padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
                Button(s.keepGoing) { dismiss() }.buttonStyle(Pill(style: .primary))
            }
            .padding(20)
        }
        .pageBackground()
    }
}

// MARK: - Deck options

struct DeckOptionsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    var deck: DeckEngine
    var body: some View {
        let s = progress.settings
        let str = progress.strings
        let levels = vocab.levels
        let active = s.levels.isEmpty ? (vocab.current?.defaultLevels ?? []) : s.levels
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: str.levels)
                    let idx = active.compactMap { levels.firstIndex(of: $0) }
                    LevelRangeSlider(levels: levels, lower: idx.min() ?? 0, upper: idx.max() ?? 0) { lo, hi in
                        let next = Array(levels[lo...hi])
                        if next != progress.settings.levels { progress.settings.levels = next; deck.invalidate() }
                    }
                }
                if progress.language != .la {
                    Picker("", selection: Binding(get: { s.kinds }, set: { progress.settings.kinds = $0; deck.invalidate() })) {
                        Text(str.all).tag("both"); Text(str.words).tag("words"); Text(str.phrases).tag("phrases")
                    }.pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: str.topics)
                    FlowLayout(spacing: 8) {
                        Chip(text: str.all, on: s.topics.isEmpty) { progress.settings.topics = []; deck.invalidate() }
                        ForEach(vocab.topics) { t in
                            Chip(text: t.name, on: s.topics.contains(t.id)) {
                                var tp = progress.settings.topics
                                if let i = tp.firstIndex(of: t.id) { tp.remove(at: i) } else { tp.append(t.id) }
                                progress.settings.topics = tp
                                deck.invalidate()
                            }
                        }
                    }
                }
                Toggle(isOn: Binding(get: { s.realia }, set: { progress.settings.realia = $0; deck.invalidate() })) {
                    Text(str.realLife.prefix(1).uppercased() + str.realLife.dropFirst()).fontWeight(.semibold)
                }.tint(Theme.green)
            }
            .padding(20)
        }
        .pageBackground()
    }
}

/// Wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
