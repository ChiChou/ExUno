import Foundation

enum DeckCard: Identifiable {
    case word(Int, again: Bool)
    case realia(Realia)
    var id: String {
        switch self {
        case .word(let id, let again): return "w\(id)\(again ? "+" : "")"
        case .realia(let r): return "r\(r.id)"
        }
    }
}

/// Builds and walks the session queue: due cards first, new words sprinkled in, a real-life card every fifth.
@Observable
final class DeckEngine {
    private(set) var queue: [DeckCard] = []
    private(set) var index = 0
    private var history: [Int] = []
    var revealed = false
    private(set) var built = false
    /// Roaming: random words from the deck filters, answers shown, nothing graded or logged.
    private(set) var roaming = false
    /// Bumped on every build, so a delayed advance from the previous deck (mid swipe animation) can be dropped.
    private(set) var generation = 0
    var summaryDue = false

    func invalidate() { built = false }

    var current: DeckCard? { index < queue.count ? queue[index] : nil }
    var canGoBack: Bool { roaming ? index > 0 : !history.isEmpty }

    private func levels(_ vocab: Vocabulary, _ s: PackSettings) -> [String] {
        s.levels.isEmpty ? (vocab.current?.defaultLevels ?? []) : s.levels
    }

    private func pool(_ vocab: Vocabulary, _ s: PackSettings) -> [Entry] {
        let lv = levels(vocab, s)
        return vocab.entries.filter { e in
            lv.contains(e.l)
                && (s.kinds == "both" || (s.kinds == "phrases") == e.isPhrase)
                && (s.topics.isEmpty || e.topics.contains { s.topics.contains($0) })
        }
    }

    func build(vocab: Vocabulary, progress: StudyProgress) {
        let s = progress.settings
        let p = pool(vocab, s)
        let d = StudyProgress.today()
        let kindOK: (Int) -> Bool = { id in
            guard let e = vocab.entry(id) else { return false }
            return s.kinds == "both" || (s.kinds == "phrases") == e.isPhrase
        }
        var due = progress.pack.cards.filter { $0.value.due <= d && kindOK($0.key) }.sorted { $0.value.due < $1.value.due }.map { DeckCard.word($0.key, again: false) }
        var fresh: [DeckCard] = Array(p.filter { progress.pack.cards[$0.i] == nil }.prefix(120)).shuffled()
            .prefix(max(5, progress.app.newPerDay - progress.todayLog().new)).map { DeckCard.word($0.i, again: false) }
        var q: [DeckCard] = []
        while !due.isEmpty || !fresh.isEmpty {
            if !due.isEmpty { q.append(due.removeFirst()) }
            if !due.isEmpty { q.append(due.removeFirst()) }
            if !fresh.isEmpty { q.append(fresh.removeFirst()) }
        }
        if q.isEmpty {
            let pids = Set(p.map(\.i))
            q = progress.pack.cards.filter { pids.contains($0.key) }.sorted { $0.value.due < $1.value.due }.prefix(30).map { DeckCard.word($0.key, again: false) }
        }
        if s.realia && !q.isEmpty {
            let engine = progress.engine
            var out: [DeckCard] = []
            for (i, c) in q.enumerated() { out.append(c); if (i + 1) % 5 == 0 { out.append(.realia(engine.realia())) } }
            q = out
        }
        queue = q; index = 0; history = []; revealed = false; built = true; roaming = false; summaryDue = false; generation += 1
    }

    /// `first` puts a word at the front, such as the one tapped on the Flashcard widget.
    func buildRoaming(vocab: Vocabulary, settings: PackSettings, first: Int? = nil) {
        var batch = roamBatch(vocab, settings)
        if let first, vocab.entry(first) != nil {
            batch.removeAll { $0.id == DeckCard.word(first, again: false).id }
            batch.insert(.word(first, again: false), at: 0)
        }
        queue = batch; index = 0; history = []; revealed = true; built = true; roaming = true; summaryDue = false; generation += 1
    }

    /// The whole filtered pool, shuffled up front, so roaming pages back and forth through a fixed list.
    private func roamBatch(_ vocab: Vocabulary, _ s: PackSettings) -> [DeckCard] {
        pool(vocab, s).shuffled().map { DeckCard.word($0.i, again: false) }
    }

    /// Moves to a roaming page; another shuffle is appended before the end is reached.
    func roam(to i: Int, vocab: Vocabulary, settings: PackSettings) {
        guard roaming, i >= 0, i < queue.count else { return }
        index = i
        if index >= queue.count - 3 { queue.append(contentsOf: roamBatch(vocab, settings)) }
    }

    func advance(_ g: Grade, vocab: Vocabulary, progress: StudyProgress) {
        guard let c = current else { return }
        if roaming { return roam(to: index + 1, vocab: vocab, settings: progress.settings) }
        switch c {
        case .word(let id, _):
            progress.grade(id, g)
            if g == .again { queue.insert(.word(id, again: true), at: min(queue.count, index + 4)) }
            let n = progress.todayLog().reviews
            if n > 0 && n % progress.app.goal == 0 { summaryDue = true }
        case .realia:
            progress.logRealia(correct: g != .again)
        }
        history.append(index)
        index += 1
        revealed = false
        if index >= queue.count { refill(vocab: vocab, progress: progress) }
    }

    private func refill(vocab: Vocabulary, progress: StudyProgress) {
        let s = progress.settings
        var more: [DeckCard] = Array(pool(vocab, s).filter { progress.pack.cards[$0.i] == nil }.prefix(80)).shuffled().prefix(10).map { DeckCard.word($0.i, again: false) }
        if more.isEmpty {
            more = progress.pack.cards.keys.filter { vocab.entry($0) != nil }.shuffled().prefix(10).map { DeckCard.word($0, again: false) }
        }
        if s.realia && more.count > 3 { more.insert(.realia(progress.engine.realia()), at: 3) }
        queue.append(contentsOf: more)
    }

    func back() {
        if roaming { index = max(0, index - 1); return }
        guard let i = history.popLast() else { return }
        index = i
        revealed = true
    }
}
