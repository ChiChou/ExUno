import SwiftUI

struct ToolsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Router.self) private var router
    @State private var path: [ToolKind] = []
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var previewDate = Date()

    var body: some View {
        let engine = progress.engine
        let previews = engine.tools.filter { $0 != .verbs }.map { ToolPreview(tool: $0, engine: engine, now: previewDate) }
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(progress.strings.tools)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Spacer(minLength: 8)
                            Text(progress.language.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Theme.surface2, in: Capsule())
                                .accessibilityLabel(progress.language.englishName)
                        }
                        Text("Numbers, dates and everyday language.")
                            .font(.subheadline).foregroundStyle(Theme.ink2)
                    }
                    if let first = previews.first {
                        NavigationLink(value: first.tool) {
                            ToolTile(preview: first, featured: true)
                        }.buttonStyle(.plain)
                    }
                    if previews.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IN EVERYDAY LIFE")
                                .font(.caption.weight(.semibold)).tracking(1.2)
                                .foregroundStyle(Theme.ink2)
                            LazyVGrid(columns: typeSize.isAccessibilitySize
                                      ? [GridItem(.flexible())]
                                      : [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                                ForEach(previews.dropFirst()) { preview in
                                    NavigationLink(value: preview.tool) {
                                        ToolTile(preview: preview)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ToolKind.self) { ToolPage(tool: $0) }
        }
        .onAppear { consumeDeepLink() }
        .onChange(of: router.tool) { _, _ in consumeDeepLink() }
        .task(id: scenePhase == .active && router.tab == .tools && path.isEmpty) {
            guard scenePhase == .active, router.tab == .tools, path.isEmpty else { return }
            previewDate = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                let now = Date()
                if !Calendar.current.isDate(now, equalTo: previewDate, toGranularity: .minute) {
                    previewDate = now
                }
            }
        }
    }

    private func consumeDeepLink() {
        guard let t = router.tool else { return }
        router.tool = nil
        if progress.engine.tools.contains(t) { path = [t] }
    }
}

/// Examples use the same offline engines as the converters; time and date are live.
private struct ToolPreview: Identifiable {
    let tool: ToolKind
    let title: String
    let value: String
    let phrase: String
    var id: ToolKind { tool }

    init(tool: ToolKind, engine: LanguageEngine, now: Date) {
        self.tool = tool
        title = engine.title(tool)
        var input = ToolInput()
        input.mode = "number"
        input.hour = Calendar.current.component(.hour, from: now)
        input.minute = Calendar.current.component(.minute, from: now)
        input.date = now
        switch tool {
        case .numbers: input.text = "42"; value = "42"
        case .numerals: input.text = "XLII"; value = "XLII → 42"
        case .prices: input.text = "12,50"; value = "€12,50"
        case .time: value = String(format: "%02d:%02d", input.hour, input.minute)
        case .date, .calendar: value = now.formatted(date: .numeric, time: .omitted)
        case .market: input.text = "250"; value = "250 g"
        case .phone:
            input.text = engine.code == .fr ? "06 12 34 56 78" : engine.code == .es ? "612 345 678" : engine.code == .pt ? "912 345 678" : "333 1234567"
            value = input.text
        case .years: input.text = "1485"; value = "1485"
        case .verbs: value = ""
        }
        let output = try? engine.run(tool, input)
        phrase = (tool == .date ? output?.rows.first?.text : output?.headline) ?? title
    }
}

private struct ToolTile: View {
    let preview: ToolPreview
    var featured = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: preview.tool.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(featured ? Theme.onSlab : Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(featured ? Theme.onSlab.opacity(0.12) : Theme.accentSoft,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                }
                Text(preview.title)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(featured ? Theme.onSlab : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(featured ? Theme.onSlab.opacity(0.7) : Theme.ink2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(preview.value)
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .foregroundStyle(featured ? Theme.onSlab : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if featured {
                    Text(preview.phrase)
                        .font(.title3)
                        .foregroundStyle(Theme.onSlab.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(featured ? 20 : 16)
        .frame(maxWidth: .infinity, minHeight: featured ? nil : 110, alignment: .topLeading)
        .background(featured ? Theme.slab : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(featured ? Color.clear : Theme.rule, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preview.title), \(preview.value), \(preview.phrase)")
    }
}

struct ToolPage: View {
    @Environment(StudyProgress.self) private var progress
    let tool: ToolKind

    var body: some View {
        Group {
            if tool == .verbs {
                ScrollView {
                    VerbsTool().padding(.horizontal, 16).padding(.vertical, 12)
                }
            } else {
                ConverterTool(tool: tool)
            }
        }
        .pageBackground()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(progress.engine.title(tool))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

// MARK: - One converter view for every tool and language

struct ConverterTool: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    let tool: ToolKind
    @State private var input = ToolInput()
    @State private var followsClock = true

    private var marketUnits: [MarketUnit] {
        guard let pack = vocab.current, pack.code == progress.language else { return [] }
        return pack.marketUnits
    }

    private var isClockTool: Bool { tool == .time || tool == .date || tool == .calendar }
    private var clockIsRunning: Bool {
        isClockTool && followsClock && scenePhase == .active && router.tab == .tools
    }

    var body: some View {
        let engine = progress.engine
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                output(engine)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                inputArea(engine)
            }
            .padding(16)
            .background(Theme.surface2)
            .overlay(alignment: .top) { Divider() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(progress.strings.done) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear(perform: setDefaults)
        .task(id: clockIsRunning) {
            guard clockIsRunning else { return }
            syncClock()
            // This timer is cancelled when the page leaves, the app backgrounds,
            // or the learner selects a custom value. Only changed values redraw.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                syncClock()
            }
        }
    }

    private func syncClock() {
        guard followsClock else { return }
        let now = Date()
        let calendar = Calendar.current
        if tool == .time {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            if input.hour != hour { input.hour = hour }
            if input.minute != minute { input.minute = minute }
        } else if tool == .date || tool == .calendar {
            if !calendar.isDate(input.date, inSameDayAs: now) { input.date = now }
        }
    }

    private func useCurrentValue() {
        followsClock = true
        syncClock()
    }

    private func selected<Value>(_ keyPath: WritableKeyPath<ToolInput, Value>) -> Binding<Value> {
        Binding(get: { input[keyPath: keyPath] }, set: { value in
            followsClock = false
            input[keyPath: keyPath] = value
        })
    }

    private func setDefaults() {
        let now = Date()
        input.hour = Calendar.current.component(.hour, from: now)
        input.minute = Calendar.current.component(.minute, from: now)
        input.date = now
        input.mode = "number"
        input.form = progress.engine.ordinalForms.first?.id ?? ""
        switch tool {
        case .numbers: input.text = "1234"
        case .numerals: input.text = "MMXXVI"
        case .prices: input.text = "12,50"
        case .phone: input.text = progress.language == .fr ? "06 12 34 56 78" : progress.language == .es ? "612 345 678" : progress.language == .pt ? "912 345 678" : "333 1234567"
        case .market:
            let unit = marketUnits.first ?? .gram
            input.text = unit.defaultText
            input.unit = unit.rawValue
        case .years: input.text = progress.language == .la ? "753" : "1485"
        default: break
        }
    }

    @ViewBuilder
    private func inputArea(_ engine: LanguageEngine) -> some View {
        switch tool {
        case .numbers, .numerals:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(engine.numberModes) { m in Chip(text: m.label, on: input.mode == m.id) { input.mode = m.id } } }
            }
            BigField(text: $input.text, placeholder: tool == .numerals ? "2026 · MMXXVI" : "123", keyboard: tool == .numerals ? .asciiCapable : .numbersAndPunctuation)
            if input.mode == "ordinal" {
                Picker("", selection: $input.form) { ForEach(engine.ordinalForms) { Text($0.label).tag($0.id) } }.pickerStyle(.segmented)
            }
        case .prices:
            BigField(text: $input.text, placeholder: "0,00", prefix: "€")
        case .time:
            HStack {
                Text(followsClock ? "Current time" : "Selected time")
                    .font(.subheadline).foregroundStyle(Theme.ink2)
                Spacer()
                Button("Now", action: useCurrentValue).disabled(followsClock)
            }
            HStack(spacing: 12) {
                InteractiveClock(hour: selected(\.hour), minute: selected(\.minute)) {
                    followsClock = false
                }
                .frame(width: 100, height: 100)
                HStack(spacing: 4) {
                    Picker("Hour", selection: selected(\.hour)) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    Text(":").font(Theme.mono(28))
                    Picker("Minutes", selection: selected(\.minute)) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                }
                .pickerStyle(.wheel).frame(height: 100)
            }
        case .date, .calendar:
            HStack {
                DatePicker("Date", selection: selected(\.date), displayedComponents: .date)
                    .datePickerStyle(.compact).tint(Theme.accent)
                    .font(.headline)
                Button("Today", action: useCurrentValue).disabled(followsClock)
            }.frame(minHeight: 44)
        case .phone:
            BigField(text: $input.text, placeholder: "06 12 34 56 78", keyboard: .phonePad)
        case .market:
            HStack(spacing: 12) {
                BigField(text: $input.text, placeholder: "250", keyboard: .decimalPad)
                    .accessibilityLabel("Quantity")
                Picker("Unit", selection: $input.unit) {
                    ForEach(marketUnits) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 88, height: 100)
                .clipped()
                .accessibilityLabel("Unit")
                .onChange(of: input.unit) { previous, current in
                    guard let old = MarketUnit(rawValue: previous), let next = MarketUnit(rawValue: current) else { return }
                    input.text = old.converted(input.text, to: next)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let unit = MarketUnit(rawValue: input.unit) {
                        ForEach(unit.presets, id: \.self) { quantity in
                            Chip(text: unit.display(quantity), on: input.text == quantity) { input.text = quantity }
                        }
                    }
                }
            }
        case .years:
            BigField(text: $input.text, placeholder: "1485", keyboard: progress.language == .la ? .asciiCapable : .numberPad)
        case .verbs:
            EmptyView()
        }
    }

    @ViewBuilder
    private func output(_ engine: LanguageEngine) -> some View {
        let needsText = [.numbers, .numerals, .prices, .phone, .market, .years].contains(tool)
        if !needsText || !input.text.trimmingCharacters(in: .whitespaces).isEmpty {
            switch Result(catching: { try engine.run(tool, input) }) {
            case .success(let out):
                Readout(label: out.label, text: out.headline, sub: isClockTool ? nil : out.sub,
                        minimumTextLines: tool == .time ? 2 : 1)
                if !out.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Other ways to say it")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink2)
                        ForEach(out.rows) { AltRow(label: $0.label, text: $0.text) }
                    }
                }
            case .failure(let e):
                ErrorReadout(message: e.localizedDescription)
            }
        }
    }
}

// MARK: - Verbs

struct VerbsTool: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    @State private var input: String
    init(preset: String? = nil) { _input = State(initialValue: preset ?? "") }

    private var defaultVerb: String {
        switch progress.language { case .it: return "andare"; case .es: return "tener"; case .fr: return "aller"; case .la: return "capiō"; case .pt: return "falar" }
    }

    var body: some View {
        let q = input.trimmingCharacters(in: .whitespaces).lowercased()
        let entry = vocab.find(lemma: q)
        VStack(alignment: .leading, spacing: 12) {
            SearchField(text: $input, placeholder: defaultVerb)
            let suggestions = vocab.verbs(matching: q)
            if !q.isEmpty && !suggestions.contains(where: { $0.word.lowercased() == q }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(suggestions) { e in Chip(text: "\(e.word) · \(e.translation.split(separator: ",").first.map(String.init) ?? "")", on: false) { input = e.word } } }
                }
            }
            if let c = progress.engine.conjugate(q, hint: entry?.verbHint) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: c.kind, color: Theme.onSlab.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(c.lemma).font(Theme.display(22, weight: .semibold))
                        if let entry { Text("· \(entry.translation)").font(.subheadline).foregroundStyle(Theme.onSlab.opacity(0.7)).lineLimit(2) }
                    }.foregroundStyle(Theme.onSlab)
                    if let f = entry?.forms { Text(f).font(Theme.mono(13)).foregroundStyle(Theme.onSlab.opacity(0.7)) }
                    HStack { Spacer(); SpeakButton(text: c.lemma, onDark: true) }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.slab, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                ForEach(c.tenses) { t in
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) { Text(t.name).font(Theme.display(16)); Spacer(); Text(t.note).font(.caption).foregroundStyle(Theme.ink2) }
                            ForEach(Array(t.forms.enumerated()), id: \.offset) { i, f in
                                HStack(spacing: 10) {
                                    if i < c.pronouns.count { Text(c.pronouns[i]).foregroundStyle(Theme.ink2).frame(width: 74, alignment: .leading) }
                                    Text(f).fontWeight(.semibold)
                                }
                            }
                            HStack { Spacer(); SpeakButton(text: t.forms.joined(separator: ", "), small: true) }
                        }
                    }
                }
            } else if !q.isEmpty {
                ErrorReadout(message: "Type a verb in its dictionary form.")
            }
        }
        .onAppear { if input.isEmpty { input = defaultVerb } }
    }
}
