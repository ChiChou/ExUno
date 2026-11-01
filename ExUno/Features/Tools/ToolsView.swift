import SwiftUI

struct ToolsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Router.self) private var router
    @State private var path: [ToolKind] = []

    var body: some View {
        let engine = progress.engine
        let tools = engine.tools.filter { $0 != .verbs }   // the conjugator lives in the Grammar tab
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(progress.strings.tools).font(Theme.display(34))
                    VStack(spacing: 0) {
                        ForEach(tools) { tool in
                            NavigationLink(value: tool) { ToolRow(tool: tool, title: engine.title(tool)) }.buttonStyle(.plain)
                            if tool != tools.last { Divider().padding(.leading, 66) }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ToolKind.self) { ToolPage(tool: $0) }
        }
        .onAppear { consumeDeepLink() }
        .onChange(of: router.tool) { _, _ in consumeDeepLink() }
    }

    private func consumeDeepLink() {
        guard let t = router.tool else { return }
        router.tool = nil
        if progress.engine.tools.contains(t) { path = [t] }
    }
}

struct ToolRow: View {
    let tool: ToolKind
    let title: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tool.icon)
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct ToolPage: View {
    @Environment(StudyProgress.self) private var progress
    let tool: ToolKind
    @State private var drill = false

    var body: some View {
        let s = progress.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if tool.hasDrill {
                    Picker("", selection: $drill) { Text(s.write).tag(false); Text(s.listen).tag(true) }.pickerStyle(.segmented)
                }
                if drill && tool.hasDrill {
                    DrillView(tool: tool)
                } else if tool == .verbs {
                    VerbsTool()
                } else {
                    ConverterTool(tool: tool)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
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
    let tool: ToolKind
    @State private var input = ToolInput()

    var body: some View {
        let engine = progress.engine
        VStack(alignment: .leading, spacing: 12) {
            inputArea(engine)
            output(engine)
        }
        .onAppear(perform: setDefaults)
    }

    private func setDefaults() {
        let now = Date()
        input.hour = Calendar.current.component(.hour, from: now)
        input.minute = Calendar.current.component(.minute, from: now) / 5 * 5
        input.date = now
        input.mode = "number"
        input.form = progress.engine.ordinalForms.first?.id ?? ""
        switch tool {
        case .numbers: input.text = "1234"
        case .numerals: input.text = "MMXXVI"
        case .prices: input.text = "12,50"
        case .phone: input.text = progress.language == .fr ? "06 12 34 56 78" : progress.language == .es ? "612 345 678" : "333 1234567"
        case .market: input.text = "250"; input.unit = "g"
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
            HStack(spacing: 8) {
                Picker("Hour", selection: $input.hour) { ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
                Text(":").font(Theme.mono(28))
                Picker("Minutes", selection: $input.minute) { ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
            }
            .pickerStyle(.wheel).frame(height: 120)
            HStack { Spacer(); ClockFace(hour: input.hour, minute: input.minute).frame(width: 150, height: 150); Spacer() }
        case .date, .calendar:
            DatePicker("", selection: $input.date, displayedComponents: .date)
                .datePickerStyle(.graphical).tint(Theme.accent).labelsHidden()
                .padding(8).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .phone:
            BigField(text: $input.text, placeholder: "06 12 34 56 78", keyboard: .phonePad)
        case .market:
            Picker("", selection: $input.unit) { Text("g").tag("g"); Text("ml").tag("ml") }.pickerStyle(.segmented)
                .onChange(of: input.unit) { _, u in input.text = u == "g" ? "250" : "500" }
            BigField(text: $input.text, placeholder: "250", keyboard: .numberPad, suffix: input.unit)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(input.unit == "g" ? [100, 200, 250, 500, 750, 1000, 1500, 2000] : [250, 330, 500, 750, 1000, 1500], id: \.self) { q in
                        Chip(text: RealiaFormat.quantity(q, input.unit), on: input.text == "\(q)") { input.text = "\(q)" }
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
                Readout(label: out.label, text: out.headline, sub: out.sub)
                ForEach(out.rows) { AltRow(label: $0.label, text: $0.text) }
            case .failure(let e):
                ErrorReadout(message: e.localizedDescription)
            }
        }
    }
}

// MARK: - Drill: hear the language, type the digits

struct DrillView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    let tool: ToolKind
    @State private var item: DrillItem?
    @State private var input = ""
    @State private var answered = false
    @State private var wasCorrect = false
    @State private var showText = false

    private var score: DrillScore { progress.pack.drills[tool.rawValue] ?? DrillScore() }

    var body: some View {
        let s = progress.strings
        VStack(spacing: 14) {
            if let item {
                DrillPrompt(item: item, header: "\(score.correct) / \(score.total) · \(score.run) · \(score.best)", revealed: answered, showText: $showText)
                AnswerField(placeholder: item.placeholder, text: $input, onSubmit: check)
                if answered {
                    Text(wasCorrect ? s.right : s.was(item.answer)).font(.headline).foregroundStyle(wasCorrect ? Theme.green : Theme.red)
                }
                Button(answered ? s.next : s.check, action: check).buttonStyle(Pill(style: .primary))
            }
        }
        .onAppear { if item == nil { next() } }
    }

    private func next() {
        let it = progress.engine.drill(tool)
        item = it
        input = ""; answered = false; showText = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { speech.speak(it.spoken, id: "speak:" + it.spoken) }
    }

    private func check() {
        guard let item else { return }
        if answered { next(); return }
        wasCorrect = item.check(input)
        answered = true
        var sc = score
        sc.total += 1
        if wasCorrect { sc.correct += 1; sc.run += 1; sc.best = max(sc.best, sc.run) } else { sc.run = 0 }
        progress.pack.drills[tool.rawValue] = sc
    }
}

// MARK: - Verbs

struct VerbsTool: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    @State private var input: String
    init(preset: String? = nil) { _input = State(initialValue: preset ?? "") }

    private var defaultVerb: String {
        switch progress.language { case .it: return "andare"; case .es: return "tener"; case .fr: return "aller"; case .la: return "capiō" }
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
