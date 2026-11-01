import Foundation

enum StudyMode: String, Codable, CaseIterable { case flow, recall }

/// Per-language deck preferences.
struct PackSettings: Codable, Equatable {
    var levels: [String] = []
    var kinds = "both"          // both / words / phrases
    var topics: [String] = []
    var realia = true
    var mode = StudyMode.flow
}

/// Settings shared by every language.
struct AppSettings: Codable, Equatable {
    var language = LanguageCode.it
    var onboarded = false
    var goal = 20
    var newPerDay = 15
    var rate = 0.95
    var currency = "USD"
    var voices: [String: String] = [:]     // language code → voice identifier
    var modified = Date.distantPast
}

/// Spaced-repetition state for one entry. Days are counted from the Unix epoch in local time.
struct CardState: Codable, Equatable {
    var due = 0
    var interval = 0
    var ease = 2.5
    var reps = 0
    var lapses = 0
    var lastSeen = 0
    var added = 0
}

struct DayLog: Codable, Equatable {
    var reviews = 0
    var good = 0
    var again = 0
    var new = 0
}

struct DrillScore: Codable, Equatable {
    var correct = 0
    var total = 0
    var run = 0
    var best = 0
}

struct Challenge: Codable, Equatable {
    var day = 0
    var index = 0
    var correct = 0
    var done = false
}

struct PackProgress: Codable, Equatable {
    var cards: [Int: CardState] = [:]
    var log: [Int: DayLog] = [:]
    var drills: [String: DrillScore] = [:]
    var challenge = Challenge()
    var settings = PackSettings()
    var settingsModified = Date.distantPast

    /// Combine two devices' histories without losing reviews from either.
    func merged(with other: PackProgress) -> PackProgress {
        var out = self
        for (id, theirs) in other.cards {
            if let mine = out.cards[id] {
                if (theirs.reps, theirs.lastSeen) > (mine.reps, mine.lastSeen) { out.cards[id] = theirs }
            } else { out.cards[id] = theirs }
        }
        for (day, theirs) in other.log {
            let mine = out.log[day] ?? DayLog()
            out.log[day] = DayLog(reviews: max(mine.reviews, theirs.reviews), good: max(mine.good, theirs.good), again: max(mine.again, theirs.again), new: max(mine.new, theirs.new))
        }
        for (k, theirs) in other.drills {
            let mine = out.drills[k] ?? DrillScore()
            out.drills[k] = theirs.total > mine.total ? DrillScore(correct: theirs.correct, total: theirs.total, run: theirs.run, best: max(mine.best, theirs.best))
                                                      : DrillScore(correct: mine.correct, total: mine.total, run: mine.run, best: max(mine.best, theirs.best))
        }
        if other.challenge.day > out.challenge.day || (other.challenge.day == out.challenge.day && other.challenge.index > out.challenge.index) {
            out.challenge = other.challenge
        }
        if other.settingsModified > out.settingsModified { out.settings = other.settings; out.settingsModified = other.settingsModified }
        return out
    }
}

enum Grade: Int { case again = 0, good = 1, easy = 2 }

/// The writable store: one file per language plus shared settings, mirrored to iCloud.
@Observable
final class StudyProgress {
    var app = AppSettings() { didSet { if !quiet && app != oldValue { saveApp() } } }
    /// Progress for the current language.
    var pack = PackProgress() { didSet { if pack != oldValue { savePack() } } }
    @ObservationIgnored private var loadedCode: LanguageCode?
    /// Set while loading or merging so those assignments aren't written back as new edits.
    @ObservationIgnored private var quiet = false
    @ObservationIgnored let cloud = CloudSync()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored var onPackChange: (() -> Void)?

    static func today() -> Int {
        let tz = TimeZone.current.secondsFromGMT()
        return Int((Date().timeIntervalSince1970 + Double(tz)) / 86_400)
    }

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ExUno", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static func packURL(_ code: LanguageCode) -> URL { directory.appendingPathComponent("progress-\(code.rawValue).json") }
    private static var appURL: URL { directory.appendingPathComponent("settings.json") }

    init() {
        migrateV1()
        quiet = true
        if let d = try? Data(contentsOf: Self.appURL), let a = try? JSONDecoder().decode(AppSettings.self, from: d) { app = a }
        if let remote = cloud.loadApp(), remote.modified > app.modified { app = remote }
        quiet = false
        cloud.onRemoteChange = { [weak self] in self?.pullFromCloud() }
        cloud.start()
        switchTo(app.language)
    }

    /// Loads (or creates) the progress file for a language.
    func switchTo(_ code: LanguageCode) {
        flushPack()
        loadedCode = nil
        var p = PackProgress()
        if let d = try? Data(contentsOf: Self.packURL(code)), let local = try? JSONDecoder().decode(PackProgress.self, from: d) { p = local }
        if let remote = cloud.loadPack(code) { p = p.merged(with: remote) }
        loadedCode = code
        pack = p
        if app.language != code { app.language = code }
    }

    var settings: PackSettings {
        get { pack.settings }
        set { pack.settings = newValue; pack.settingsModified = Date() }
    }

    private func saveApp() {
        quiet = true
        app.modified = Date()
        quiet = false
        if let d = try? JSONEncoder().encode(app) { try? d.write(to: Self.appURL, options: .atomic) }
        cloud.saveApp(app)
        WidgetBridge.language = app.language
    }

    private func savePack() {
        guard let code = loadedCode else { return }
        onPackChange?()
        saveTask?.cancel()
        let snapshot = pack
        saveTask = Task { [cloud] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: Self.packURL(code), options: .atomic) }
            cloud.savePack(snapshot, for: code)
        }
    }

    private func flushPack() {
        guard let code = loadedCode else { return }
        saveTask?.cancel()
        if let d = try? JSONEncoder().encode(pack) { try? d.write(to: Self.packURL(code), options: .atomic) }
        cloud.savePack(pack, for: code)
    }

    private func pullFromCloud() {
        if let remote = cloud.loadApp(), remote.modified > app.modified {
            let lang = app.language
            quiet = true
            app = remote
            quiet = false
            if let d = try? JSONEncoder().encode(remote) { try? d.write(to: Self.appURL, options: .atomic) }
            if remote.language != lang { switchTo(remote.language); return }
        }
        if let code = loadedCode, let remote = cloud.loadPack(code) {
            let m = pack.merged(with: remote)
            if m != pack { pack = m }
        }
    }

    /// Moves the single-file progress from the first build into the Italian pack.
    private func migrateV1() {
        let old = Self.directory.appendingPathComponent("progress.json")
        guard FileManager.default.fileExists(atPath: old.path) else { return }
        struct V1: Codable { var cards: [Int: CardState]; var log: [Int: DayLog]; var drills: [String: DrillScore]? }
        if let d = try? Data(contentsOf: old), let v1 = try? JSONDecoder().decode(V1.self, from: d), !FileManager.default.fileExists(atPath: Self.packURL(.it).path) {
            var p = PackProgress()
            p.cards = v1.cards; p.log = v1.log; p.drills = v1.drills ?? [:]
            if let out = try? JSONEncoder().encode(p) { try? out.write(to: Self.packURL(.it)) }
            var a = AppSettings(); a.onboarded = true; a.language = .it
            if let out = try? JSONEncoder().encode(a) { try? out.write(to: Self.appURL) }
        }
        try? FileManager.default.removeItem(at: old)
    }

    // MARK: Study

    func todayLog() -> DayLog { pack.log[Self.today()] ?? DayLog() }

    func dueCardIDs() -> [Int] {
        let d = Self.today()
        return pack.cards.filter { $0.value.due <= d }.map(\.key)
    }

    var streak: Int {
        var d = Self.today(), n = 0
        if pack.log[d] == nil { d -= 1 }
        while let l = pack.log[d], l.reviews > 0 { n += 1; d -= 1 }
        return n
    }

    /// SM-2 style schedule. Again returns today, Good follows the ease, Easy stretches it.
    func grade(_ id: Int, _ g: Grade) {
        let d = Self.today()
        var c = pack.cards[id] ?? CardState(added: d)
        let isNew = c.reps == 0
        c.reps += 1
        c.lastSeen = d
        switch g {
        case .again: c.interval = 0; c.lapses += 1; c.ease = max(1.3, c.ease - 0.2)
        case .good: c.interval = isNew ? 1 : max(1, Int((Double(c.interval) * c.ease).rounded()))
        case .easy:
            c.interval = isNew ? 3 : max(1, Int((Double(c.interval) * c.ease * 1.3).rounded()))
            if !isNew { c.ease += 0.15 }
        }
        c.due = d + c.interval
        var p = pack
        p.cards[id] = c
        var l = p.log[d] ?? DayLog()
        l.reviews += 1
        if g == .again { l.again += 1 } else { l.good += 1 }
        if isNew { l.new += 1 }
        p.log[d] = l
        pack = p
    }

    func logRealia(correct: Bool) {
        let d = Self.today()
        var l = pack.log[d] ?? DayLog()
        l.reviews += 1
        if correct { l.good += 1 } else { l.again += 1 }
        pack.log[d] = l
    }

    func nextInterval(_ id: Int, _ g: Grade, strings: UIStrings) -> String {
        guard let c = pack.cards[id], c.reps > 0 else { return strings.days(g == .easy ? 3 : 1) }
        return strings.days(max(1, Int((Double(c.interval) * c.ease * (g == .easy ? 1.3 : 1)).rounded())))
    }

    func addToDeck(_ id: Int) {
        let d = Self.today()
        pack.cards[id] = CardState(due: d, added: d)
    }
    func removeFromDeck(_ id: Int) { pack.cards.removeValue(forKey: id) }

    func resetCurrentLanguage() { pack = PackProgress(settings: pack.settings, settingsModified: pack.settingsModified) }
}
