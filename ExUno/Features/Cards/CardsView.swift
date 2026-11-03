import SwiftUI

struct CardsView: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    @Environment(Router.self) private var router
    var deck: DeckEngine
    @State private var showOptions = false
    @State private var showSummary = false
    @State private var dragOffset: CGFloat = 0
    @State private var leaving: CGFloat = 0
    @State private var cardKey = 0
    @State private var dragY: CGFloat = 0
    @State private var returning = false
    @State private var transitioning = false
    @State private var contentAtTop = true
    @State private var trackingDrag = false
    @State private var dragBeganAtTop = true
    @State private var voiceOver = UIAccessibility.isVoiceOverRunning
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Per device and not synced: roaming is a way to look around, not part of study progress.
    /// It is the default; the last mode picked is kept here and in the synced study mode.
    @AppStorage("cards.roaming") private var roaming = true

    private var settings: PackSettings { progress.settings }
    private var playfulRecall: Bool { !roaming && settings.mode == .recall }

    var body: some View {
        let s = progress.strings
        VStack(spacing: 14) {
            topBar
            if !vocab.isReady {
                Spacer()
                if let error = vocab.error { Text(error).foregroundStyle(Theme.ink2).multilineTextAlignment(.center).padding() } else { ProgressView() }
                Spacer()
            } else if let card = deck.current {
                if deck.roaming { roamPager } else { stage(card) }
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
        .onAppear { if !openWidgetCard() && vocab.isReady && (!deck.built || deck.roaming != roaming) { rebuild() } }
        .onChange(of: vocab.isReady) { _, ready in if ready && !openWidgetCard() && !deck.built { rebuild() } }
        .onChange(of: router.card) { _, _ in openWidgetCard() }
        .onChange(of: deck.summaryDue) { _, due in if due { deck.summaryDue = false; showSummary = true } }
        .sheet(isPresented: $showOptions, onDismiss: { if !deck.built { rebuild() } }) {
            DeckOptionsView(deck: deck).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSummary) { SessionSummaryView().presentationDetents([.medium, .large]) }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            voiceOver = UIAccessibility.isVoiceOverRunning
        }
        .onDisappear { speech.stop() }
    }

    private func rebuild() {
        if roaming { deck.buildRoaming(vocab: vocab, settings: settings) } else { deck.build(vocab: vocab, progress: progress) }
        cardKey += 1
    }

    /// A word tapped on the Flashcard widget opens here roaming from it, since the widget roams too and a study mode would grade it.
    @discardableResult
    private func openWidgetCard() -> Bool {
        guard vocab.isReady, let id = router.card else { return false }
        router.card = nil
        roaming = true
        deck.buildRoaming(vocab: vocab, settings: settings, first: id)
        cardKey += 1
        speech.stop()
        return true
    }

    /// Flow and Recall are the synced study modes; Roam is a local, untracked browse.
    private enum ModeChoice: Hashable { case study(StudyMode), roam }

    private func selectMode(_ choice: ModeChoice) {
        let wasRoaming = roaming
        switch choice {
        case .roam: roaming = true
        case .study(let mode): roaming = false; progress.settings.mode = mode
        }
        if roaming != wasRoaming { rebuild() } else { deck.revealed = false }
        resetDrag()
        speech.stop()
    }

    private func modeTab(_ title: String, choice: ModeChoice) -> some View {
        let selected = choice == (roaming ? .roam : .study(settings.mode))
        return Button { selectMode(choice) } label: {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Capsule().fill(Theme.accent).frame(width: 20, height: 3)
                        .opacity(selected ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(transitioning)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(choice == .roam ? "Browse without recording progress" : choice == .study(.flow) ? "Study with meanings visible" : "Remember the meaning before revealing it")
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                modeTab("Roam", choice: .roam)
                modeTab("Flow", choice: .study(.flow))
                modeTab("Recall", choice: .study(.recall))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Study mode")
            Spacer(minLength: 0)
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

    /// Roaming pages through the prewarmed shuffle: swipe left for the next word, right for the previous one.
    private var roamPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(deck.queue.indices, id: \.self) { i in
                    if case .word(let id, _) = deck.queue[i], let e = vocab.entry(id) {
                        WordCardView(entry: e, showAnswer: true, reveal: {})
                            .padding(.horizontal, 16)
                            .containerRelativeFrame([.horizontal, .vertical])
                            // Tilts away while sliding, like the thrown cards of the study modes; pivoting on the bottom keeps neighbours apart.
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.rotationEffect(.degrees(phase.value * 14), anchor: .bottom)
                            }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding<Int?>(get: { deck.index }, set: { i in
            guard let i, i != deck.index else { return }
            deck.roam(to: i, vocab: vocab, settings: settings)
            speech.stop()
        }))
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .id(deck.generation)
        .padding(.horizontal, -16)
        .frame(maxHeight: .infinity)
    }

    /// The previous and next buttons slide the roaming pager like a swipe would.
    private func roamStep(_ by: Int) {
        speech.stop()
        withAnimation(.snappy(duration: 0.3)) { deck.roam(to: deck.index + by, vocab: vocab, settings: settings) }
    }

    @ViewBuilder
    private func cardFace(_ card: DeckCard, shown: Bool) -> some View {
        switch card {
        case .word(let id, let again):
            if let entry = vocab.entry(id) {
                WordCardView(entry: entry, again: again, showAnswer: shown,
                             reveal: { deck.revealed = true },
                             onScrollTopChange: { if !playfulRecall || deck.revealed == shown { contentAtTop = $0 } })
            } else {
                Color.clear.onAppear { deck.advance(.good, vocab: vocab, progress: progress) }
            }
        case .realia(let realia):
            RealiaCardView(realia: realia, showAnswer: shown, reveal: { deck.revealed = true },
                           onScrollTopChange: { if !playfulRecall || deck.revealed == shown { contentAtTop = $0 } })
        }
    }

    private func stage(_ card: DeckCard) -> some View {
        ZStack {
            if playfulRecall {
                RoundedRectangle(cornerRadius: 26).fill(Theme.surface2)
                    .scaleEffect(x: 0.94, y: 0.97).offset(y: 10).accessibilityHidden(true)
                RecallFlip(revealed: deck.revealed) {
                    cardFace(card, shown: false)
                } back: {
                    cardFace(card, shown: true)
                }
            } else {
                cardFace(card, shown: isShown(card))
            }
        }
        .overlay(alignment: .top) {
            if playfulRecall && deck.revealed && (abs(dragOffset) > 18 || dragY > 18) {
                Label(dragY > abs(dragOffset) ? progress.strings.again : progress.strings.next,
                      systemImage: dragY > abs(dragOffset) ? "arrow.down" : "arrow.right")
                    .font(.headline).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule())
                    .padding(.top, 16).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .id(cardKey)
        .offset(x: reduceMotion ? 0 : dragOffset + leaving * 600, y: reduceMotion ? 0 : dragY)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset + leaving * 600) / 30))
        .scaleEffect(returning && !reduceMotion ? 0.95 : 1)
        .opacity(leaving == 0 ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.28), value: leaving)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    guard !transitioning else { return }
                    if !trackingDrag { trackingDrag = true; dragBeganAtTop = contentAtTop }
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                        dragY = 0
                    } else if playfulRecall && dragBeganAtTop && value.translation.height > 0 {
                        dragY = min(125, value.translation.height * 0.55)
                        dragOffset = 0
                    }
                }
                .onEnded { value in
                    trackingDrag = false
                    guard !transitioning else { return }
                    if playfulRecall {
                        let action = RecallSwipe.action(translation: value.translation, predicted: value.predictedEndTranslation)
                        if !deck.revealed && action != nil {
                            resetDrag()
                            deck.revealed = true
                        } else if action == .repeatSoon && dragBeganAtTop {
                            repeatCard()
                        } else if action == .moveOn {
                            leave(.good, direction: value.translation.width < 0 ? -1 : 1)
                        } else { resetDrag() }
                    } else if abs(value.translation.width) > 90 && abs(value.translation.width) > abs(value.translation.height) {
                        if !isShown(card) { resetDrag(); deck.revealed = true }
                        else { leave(value.translation.width > 0 ? .good : .again) }
                    } else { resetDrag() }
                }
        )
        .onTapGesture { if !deck.revealed && !transitioning { deck.revealed = true } }
        .onChange(of: cardKey) { _, _ in contentAtTop = true; trackingDrag = false }
        .accessibilityActions {
            if playfulRecall {
                if deck.revealed {
                    Button(progress.strings.next) { leave(.good) }
                    Button(progress.strings.again) { repeatCard() }
                } else {
                    Button(progress.strings.showAnswer) { deck.revealed = true }
                }
            }
        }
    }

    private func resetDrag() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { dragOffset = 0; dragY = 0 }
    }

    private func finishAdvance(_ grade: Grade, generation: Int) {
        if deck.generation == generation && !deck.roaming { deck.advance(grade, vocab: vocab, progress: progress) }
        leaving = 0
        dragOffset = 0
        dragY = 0
        returning = false
        transitioning = false
        cardKey += 1
        speech.stop()
    }

    private func leave(_ grade: Grade, direction: CGFloat? = nil) {
        guard !transitioning else { return }
        transitioning = true
        leaving = direction ?? (grade == .again ? -1 : 1)
        dragOffset = 0
        dragY = 0
        let generation = deck.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.12 : 0.22)) {
            finishAdvance(grade, generation: generation)
        }
    }

    private func repeatCard() {
        guard !transitioning, deck.revealed else { return }
        transitioning = true
        let generation = deck.generation
        withAnimation(reduceMotion ? nil : .spring(duration: 0.18)) {
            dragOffset = 0
            dragY = 70
            returning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.22)) { dragY = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.15 : 0.35)) {
            finishAdvance(.again, generation: generation)
        }
    }

    private var undoButton: some View {
        Button {
            guard !transitioning, deck.undo(progress: progress) else { return }
            resetDrag()
            cardKey += 1
            speech.stop()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
        }
        .buttonStyle(.plain).foregroundStyle(Theme.ink2)
        .disabled(transitioning || !deck.canUndo(progress: progress))
    }

    @ViewBuilder
    private func controls(_ card: DeckCard, _ s: UIStrings) -> some View {
        HStack(spacing: 12) {
            if deck.roaming {
                Button { roamStep(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 44).foregroundStyle(Theme.ink2).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!deck.canGoBack).opacity(deck.canGoBack ? 1 : 0.4).accessibilityLabel("Previous card")
                Button { roamStep(1) } label: { HStack { Text(s.next); Image(systemName: "chevron.right") } }
                    .buttonStyle(Pill(style: .neutral))
            } else if playfulRecall {
                if deck.canUndo(progress: progress) { undoButton }
                if voiceOver {
                    if deck.revealed {
                        Button(s.again, action: repeatCard).buttonStyle(Pill(style: .neutral))
                        Button(s.next) { leave(.good) }.buttonStyle(Pill(style: .primary))
                    } else {
                        Button(s.showAnswer) { deck.revealed = true }.buttonStyle(Pill(style: .neutral))
                    }
                } else {
                    Text(deck.revealed ? "Flick to move on · Pull down for another look" : "Tap the card to reveal")
                        .font(.footnote).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                if deck.canUndo(progress: progress) { undoButton }
                switch card {
                case .realia where !deck.revealed:
                    Button(s.howToSay) { deck.revealed = true }.buttonStyle(Pill(style: .primary))
                case .realia:
                    Button(s.didntKnow) { leave(.again) }.buttonStyle(Pill(style: .bad))
                    Button(s.knew) { leave(.good) }.buttonStyle(Pill(style: .good))
                case .word:
                    Button(s.hard) { leave(.again) }.buttonStyle(Pill(style: .amber))
                    Button { leave(.good) } label: { HStack { Text(s.next); Image(systemName: "chevron.right") } }
                        .buttonStyle(Pill(style: .primary))
                }
            }
        }
    }
}

// MARK: - Word card

struct WordCardView: View {
    @Environment(StudyProgress.self) private var progress
    let entry: Entry
    var again = false
    let showAnswer: Bool
    let reveal: () -> Void
    var onScrollTopChange: (Bool) -> Void = { _ in }

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
        .onScrollGeometryChange(for: Bool.self) { geometry in geometry.contentOffset.y <= 1 } action: { _, top in
            onScrollTopChange(top)
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LevelRangeControl()
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
