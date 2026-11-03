import Foundation

/// One dictionary entry from a language pack (compact keys keep the files small).
struct Entry: Codable, Identifiable, Hashable {
    let i: Int
    let w: String
    let t: String
    let l: String
    let p: String
    let x: String
    let e: String
    let z: Double
    var g: String?
    var a: String?
    var k: String?
    var c: [String]?
    var m: String?
    var v: String?

    var id: Int { i }
    var word: String { w }
    var translation: String { t }
    var level: String { l }
    var pos: String { p }
    var exampleNative: String { x }
    var exampleEnglish: String { e }
    var isPhrase: Bool { k == "p" }
    var topics: [String] { c ?? [] }
    /// Latin principal parts / dictionary forms ("vōcis f.", "-ēre -uī -itum").
    var forms: String? { m }
    var verbHint: VerbHint { VerbHint(forms: m, verbClass: v) }
    var article: String { a ?? "" }

    static func == (a: Entry, b: Entry) -> Bool { a.i == b.i }
    func hash(into hasher: inout Hasher) { hasher.combine(i) }

    var wordWithArticle: String {
        let a = article
        if a.isEmpty { return w }
        return a.hasSuffix("'") ? a + w : a + " " + w
    }
    var genderLabel: String? {
        guard p == "noun", let g else { return nil }
        switch g { case "m": return "m"; case "f": return "f"; case "n": return "n"; default: return "m/f" }
    }
    /// Text for speech: Latin macrons are dropped so the voice reads them cleanly.
    var spoken: String { wordWithArticle }
}

extension String {
    /// Lowercased, accents stripped: for search.
    var folded: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en")).lowercased() }
}

struct Topic: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let icon: String
}

struct LanguagePackFile: Codable {
    let code: String
    let schema: Int
    let levels: [String]
    let defaultLevels: [String]
    let topics: [Topic]
    let entries: [Entry]
    let marketUnits: [String]?

    var availableMarketUnits: [MarketUnit] {
        var seen = Set<MarketUnit>()
        // Older packs retain the original universal g/ml selector.
        return (marketUnits ?? ["g", "ml"]).compactMap(MarketUnit.init(rawValue:))
            .filter { seen.insert($0).inserted }
    }
}

/// A loaded pack plus its search index.
final class LoadedPack {
    let code: LanguageCode
    let levels: [String]
    let defaultLevels: [String]
    let topics: [Topic]
    let entries: [Entry]
    let marketUnits: [MarketUnit]
    let byId: [Int: Entry]
    fileprivate let keys: [(word: String, translation: String)]

    init(code: LanguageCode, file: LanguagePackFile) {
        self.code = code
        levels = file.levels
        defaultLevels = file.defaultLevels
        topics = file.topics
        entries = file.entries
        marketUnits = file.availableMarketUnits
        var map: [Int: Entry] = [:]
        map.reserveCapacity(file.entries.count)
        for e in file.entries { map[e.i] = e }
        byId = map
        keys = file.entries.map { (word: $0.w.folded, translation: $0.t.folded) }
    }

    func topicName(_ id: String) -> String { topics.first { $0.id == id }?.name ?? id }
}

/// Loads language packs lazily and keeps them in memory once loaded.
@Observable
final class Vocabulary {
    private(set) var current: LoadedPack?
    private(set) var loading = false
    private(set) var error: String?
    @ObservationIgnored private var cache: [LanguageCode: LoadedPack] = [:]

    init(pack: LoadedPack? = nil) {
        current = pack
        if let pack { cache[pack.code] = pack }
    }

    var isReady: Bool { current != nil && !loading }
    var entries: [Entry] { current?.entries ?? [] }
    var levels: [String] { current?.levels ?? [] }
    var topics: [Topic] { current?.topics ?? [] }

    func load(_ code: LanguageCode) {
        if let p = cache[code] { current = p; error = nil; return }
        loading = true
        error = nil
        Task.detached(priority: .userInitiated) {
            let result: Result<LoadedPack, Error> = Result {
                guard let url = Bundle.main.url(forResource: code.rawValue, withExtension: "json", subdirectory: "Packs")
                        ?? Bundle.main.url(forResource: code.rawValue, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
                let file = try JSONDecoder().decode(LanguagePackFile.self, from: Data(contentsOf: url))
                return LoadedPack(code: code, file: file)
            }
            await MainActor.run {
                switch result {
                case .success(let p): self.cache[code] = p; self.current = p
                case .failure(let e): self.error = "The \(code.englishName) word list could not be loaded (\(e.localizedDescription))."
                }
                self.loading = false
            }
        }
    }

    func entry(_ id: Int) -> Entry? { current?.byId[id] }

    func find(lemma: String) -> Entry? {
        let f = lemma.folded
        return current?.entries.first { $0.w.folded == f }
    }

    /// Search both directions: exact, then prefix, then substring matches.
    func search(_ query: String, limit: Int = 80) -> [Entry] {
        guard let pack = current else { return [] }
        let q = query.trimmingCharacters(in: .whitespaces).folded
        guard !q.isEmpty else { return [] }
        var exact: [Entry] = [], prefix: [Entry] = [], contains: [Entry] = []
        for (idx, e) in pack.entries.enumerated() {
            let k = pack.keys[idx]
            if k.word == q || k.translation == q { exact.append(e) }
            else if k.word.hasPrefix(q) || k.translation.hasPrefix(q) || k.translation.hasPrefix("to " + q) || k.translation.contains(", " + q) { prefix.append(e) }
            else if k.word.contains(q) || k.translation.contains(q) { contains.append(e) }
            if exact.count + prefix.count >= limit { break }
        }
        return Array((exact + prefix + contains).prefix(limit))
    }

    func verbs(matching query: String, limit: Int = 8) -> [Entry] {
        guard let pack = current else { return [] }
        let q = query.folded
        guard !q.isEmpty else { return [] }
        var out: [Entry] = []
        for (idx, e) in pack.entries.enumerated() where e.p == "verb" {
            if pack.keys[idx].word.hasPrefix(q) || pack.keys[idx].translation.contains(q) { out.append(e); if out.count >= limit { break } }
        }
        return out
    }
}
