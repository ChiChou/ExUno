import SwiftUI

struct WordFilter: Hashable {
    var level: String? = nil
    var topic: String? = nil
    var phrasesOnly = false
    var deckOnly = false
}

/// Search on top; below it a compact map of the dictionary: shelves, a level strip and a topic grid.
struct WordsView: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    @State private var query = ""
    @State private var selected: Entry?
    @State private var wiktionaryTerm: String?
    @State private var counts = Counts()

    struct Counts: Equatable {
        var code: LanguageCode?
        var levels: [String: Int] = [:]
        var topics: [String: Int] = [:]
        var phrases = 0
    }

    var body: some View {
        let s = progress.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(s.words).font(Theme.display(34))
                SearchField(text: $query, placeholder: s.filter)
                if !vocab.isReady {
                    ProgressView(vocab.error ?? "").frame(maxWidth: .infinity).padding(40)
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    directories(s)
                } else {
                    let list = vocab.search(query)
                    if list.isEmpty {
                        VStack(spacing: 10) {
                            Text(s.nothingHere).foregroundStyle(Theme.ink2)
                            Button("Wiktionary") { wiktionaryTerm = query.trimmingCharacters(in: .whitespaces) }.buttonStyle(Pill(style: .ghost, compact: true))
                        }.frame(maxWidth: .infinity).padding(30)
                    } else {
                        EntryList(entries: list) { selected = $0 }
                        HStack { Spacer(); Button("Wiktionary") { wiktionaryTerm = query.trimmingCharacters(in: .whitespaces) }.buttonStyle(Pill(style: .ghost, compact: true)); Spacer() }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .pageBackground()
        .scrollDismissesKeyboard(.immediately)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: WordFilter.self) { WordListScreen(filter: $0) }
        .sheet(item: $selected) { e in WordDetailView(entry: e).presentationDetents([.large]) }
        .sheet(item: Binding(get: { wiktionaryTerm.map { WiktionaryTerm(term: $0) } }, set: { wiktionaryTerm = $0?.term })) { t in
            WiktionaryView(term: t.term).presentationDetents([.medium, .large])
        }
        .task(id: vocab.current?.code) { recount() }
    }

    private func recount() {
        guard let pack = vocab.current, counts.code != pack.code else { return }
        var c = Counts(code: pack.code)
        for e in pack.entries {
            c.levels[e.l, default: 0] += 1
            if e.isPhrase { c.phrases += 1 }
            for t in e.topics { c.topics[t, default: 0] += 1 }
        }
        counts = c
    }

    @ViewBuilder
    private func directories(_ s: UIStrings) -> some View {
        // Shelves: my deck and phrases side by side.
        HStack(spacing: 10) {
            NavigationLink(value: WordFilter(deckOnly: true)) {
                Shelf(icon: "star.fill", title: s.myDeck, count: progress.pack.cards.count, tint: Theme.amber)
            }.buttonStyle(.plain)
            if counts.phrases > 0 {
                NavigationLink(value: WordFilter(phrasesOnly: true)) {
                    Shelf(icon: "text.quote", title: s.phrases, count: counts.phrases, tint: Theme.accent)
                }.buttonStyle(.plain)
            }
        }
        Eyebrow(text: s.levels)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(max(vocab.levels.count, 1), 3)), spacing: 8) {
            ForEach(vocab.levels, id: \.self) { l in
                NavigationLink(value: WordFilter(level: l)) {
                    VStack(spacing: 2) {
                        Text(l).font(Theme.display(20)).foregroundStyle(Theme.amber)
                        Text((counts.levels[l] ?? 0).formatted()).font(.caption.monospacedDigit()).foregroundStyle(Theme.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        Eyebrow(text: s.topics)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(vocab.topics) { t in
                NavigationLink(value: WordFilter(topic: t.id)) {
                    VStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.accent)
                        Text(t.name).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                        Text((counts.topics[t.id] ?? 0).formatted()).font(.caption2.monospacedDigit()).foregroundStyle(Theme.ink2)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct Shelf: View {
    let icon: String
    let title: String
    let count: Int
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder = ""
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink2)
            TextField(placeholder, text: $text).autocorrectionDisabled().textInputAutocapitalization(.never)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink2) } }
        }
        .padding(.horizontal, 14).frame(minHeight: 50)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

/// One directory: a level, a topic, the phrases, or the learner's deck. Narrow with chips or a local filter.
struct WordListScreen: View {
    @Environment(Vocabulary.self) private var vocab
    @Environment(StudyProgress.self) private var progress
    let filter: WordFilter
    @State private var query = ""
    @State private var narrow: String? = nil
    @State private var shown = 200
    @State private var selected: Entry?

    private var title: String {
        let s = progress.strings
        if filter.deckOnly { return s.myDeck }
        if filter.phrasesOnly { return s.phrases }
        if let t = filter.topic { return vocab.current?.topicName(t) ?? t }
        return filter.level ?? s.words
    }

    private var entries: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        return vocab.entries.filter { e in
            if let l = filter.level, e.l != l { return false }
            if let t = filter.topic, !e.topics.contains(t) { return false }
            if filter.phrasesOnly && !e.isPhrase { return false }
            if filter.deckOnly && progress.pack.cards[e.id] == nil { return false }
            if let n = narrow {
                if filter.level != nil { if !e.topics.contains(n) { return false } } else if e.l != n { return false }
            }
            if !q.isEmpty && !(e.w.folded.contains(q) || e.t.folded.contains(q)) { return false }
            return true
        }
    }

    var body: some View {
        let s = progress.strings
        let list = entries
        let chips: [(String, String)] = filter.level != nil ? vocab.topics.map { ($0.id, $0.name) } : vocab.levels.map { ($0, $0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SearchField(text: $query, placeholder: s.filter)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(text: s.all, on: narrow == nil) { narrow = nil }
                        ForEach(chips, id: \.0) { c in Chip(text: c.1, on: narrow == c.0) { narrow = narrow == c.0 ? nil : c.0 } }
                    }
                }
                Text(s.entries(list.count)).font(.footnote).foregroundStyle(Theme.ink2)
                if list.isEmpty {
                    Text(s.nothingHere).foregroundStyle(Theme.ink2).frame(maxWidth: .infinity).padding(30)
                } else {
                    EntryList(entries: Array(list.prefix(shown))) { selected = $0 }
                    if list.count > shown {
                        Button("+ \(min(300, list.count - shown))") { shown += 300 }.buttonStyle(Pill(style: .ghost, compact: true)).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .pageBackground()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { e in WordDetailView(entry: e).presentationDetents([.large]) }
    }
}

struct EntryList: View {
    @Environment(StudyProgress.self) private var progress
    let entries: [Entry]
    let onSelect: (Entry) -> Void
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(entries) { e in
                Button { onSelect(e) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.wordWithArticle).fontWeight(.semibold).foregroundStyle(Theme.ink)
                            Text(e.translation).font(.subheadline).foregroundStyle(Theme.ink2).lineLimit(1)
                        }
                        Spacer()
                        if progress.pack.cards[e.id] != nil { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.amber) }
                        Tag(text: e.level, style: .level)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 1))
    }
}

struct WiktionaryTerm: Identifiable { let term: String; var id: String { term } }

struct WordDetailView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Vocabulary.self) private var vocab
    let entry: Entry
    @State private var showWiktionary = false
    @State private var showAllTenses = false

    var body: some View {
        let inDeck = progress.pack.cards[entry.id] != nil
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FlowLayout(spacing: 6) {
                    Tag(text: entry.level, style: .level)
                    if !entry.pos.isEmpty { Tag(text: entry.pos, style: .pos) }
                    if let g = entry.genderLabel { Tag(text: g, style: .gender) }
                    ForEach(entry.topics, id: \.self) { Tag(text: vocab.current?.topicName($0) ?? $0) }
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.wordWithArticle).font(Theme.display(32)).foregroundStyle(Theme.ink).textSelection(.enabled)
                        if let f = entry.forms { Text(f).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink2) }
                    }
                    Spacer()
                    Button { if inDeck { progress.removeFromDeck(entry.id) } else { progress.addToDeck(entry.id) } } label: {
                        Image(systemName: inDeck ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(inDeck ? Theme.amber : Theme.ink2)
                            .frame(width: 40, height: 40)
                            .background(inDeck ? Theme.amberSoft : Theme.surface2, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(inDeck ? "Remove from deck" : "Add to deck")
                    SpeakButton(text: entry.spoken)
                }
                Text(entry.translation).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.green)
                if !entry.exampleNative.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(entry.exampleNative).fontWeight(.semibold); Spacer(); SpeakButton(text: entry.exampleNative, small: true) }
                            Text(entry.exampleEnglish).foregroundStyle(Theme.ink2)
                        }
                    }
                }
                Button("Wiktionary") { showWiktionary = true }.buttonStyle(Pill(style: .ghost, compact: true))
                if entry.pos == "verb", let cj = progress.engine.conjugate(entry.word, hint: entry.verbHint) {
                    ForEach(showAllTenses ? cj.tenses : Array(cj.tenses.prefix(2))) { t in
                        Card(padding: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) { Text(t.name).font(Theme.display(16)); Spacer(); Text(t.note).font(.caption).foregroundStyle(Theme.ink2) }
                                ConjugationGrid(forms: t.forms, pronouns: cj.pronouns)
                            }
                        }
                    }
                    if !showAllTenses && cj.tenses.count > 2 { Button("+ \(cj.tenses.count - 2)") { showAllTenses = true }.buttonStyle(Pill(style: .ghost, compact: true)) }
                }
            }
            .padding(20)
        }
        .pageBackground()
        .sheet(isPresented: $showWiktionary) { WiktionaryView(term: entry.word).presentationDetents([.medium, .large]) }
    }
}

// MARK: - Wiktionary (online)

struct WiktionaryView: View {
    @Environment(StudyProgress.self) private var progress
    let term: String
    @State private var sections: [WiktionarySection] = []
    @State private var status: String? = "…"

    private var anchor: String {
        switch progress.language { case .it: return "Italian"; case .es: return "Spanish"; case .fr: return "French"; case .la: return "Latin" }
    }

    /// Wiktionary titles Latin pages without macrons or diaeresis (nōn → non); the headword on the page keeps them.
    private var pageTitle: String {
        progress.language == .la ? term.folding(options: .diacriticInsensitive, locale: nil) : term
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Wiktionary · \(anchor)")
                HStack { Text(term).font(Theme.display(28)); Spacer(); SpeakButton(text: term) }
                if let status { Text(status).foregroundStyle(Theme.ink2) }
                ForEach(sections) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: s.partOfSpeech)
                        ForEach(Array(s.definitions.enumerated()), id: \.offset) { i, d in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(i + 1). \(d.text)")
                                if let ex = d.example { Text(ex).font(.subheadline).foregroundStyle(Theme.ink2) }
                            }
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if let url = URL(string: "https://en.wiktionary.org/wiki/\(pageTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pageTitle)#\(anchor)") {
                    Link("en.wiktionary.org", destination: url).font(.subheadline)
                    Hint(text: "Wiktionary contributors, CC BY-SA 4.0.")
                }
            }
            .padding(20)
        }
        .pageBackground()
        .task { await lookup() }
    }

    private func lookup() async {
        let t = pageTitle.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pageTitle
        guard let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(t)?redirect=true") else { status = "—"; return }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 404 { status = "No entry found."; return }
            let decoded = try JSONDecoder().decode([String: [WiktionarySection]].self, from: data)
            if let found = decoded[progress.language.rawValue] { sections = Array(found.prefix(4)); status = nil }
            else { status = "No \(anchor) entry on Wiktionary." }
        } catch {
            status = "Could not reach Wiktionary."
        }
    }
}

struct WiktionarySection: Decodable, Identifiable {
    struct Definition: Decodable {
        let definition: String
        let examples: [String]?
        var text: String { definition.strippingHTML }
        var example: String? { examples?.first?.strippingHTML }
    }
    let partOfSpeech: String
    let definitions: [Definition]
    var id: String { partOfSpeech + "\(definitions.count)" }
}

extension String {
    var strippingHTML: String {
        var s = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (k, v) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")] { s = s.replacingOccurrences(of: k, with: v) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
