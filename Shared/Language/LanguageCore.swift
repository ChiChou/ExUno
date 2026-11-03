import Foundation

// MARK: - Languages

enum LanguageCode: String, CaseIterable, Codable, Identifiable, Hashable {
    case it, es, fr, la, pt
    case esLatAm = "es-419"
    case ptBR = "pt-BR"
    var id: String { rawValue }

    /// Languages as shown in pickers: alphabetical by native name (Español, Français, Italiano, Latīna, Português), so none comes first by design.
    /// Case order stays fixed because the daily challenge seeds on it.
    static var alphabetical: [LanguageCode] {
        allCases.sorted { $0.nativeName.compare($1.nativeName, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending }
    }

    var englishName: String {
        switch self {
        case .it: return "Italian"
        case .es: return "Spanish (Spain)"
        case .esLatAm: return "Spanish (Latin America)"
        case .fr: return "French"
        case .la: return "Latin"
        case .pt: return "Portuguese (European)"
        case .ptBR: return "Portuguese (Brazilian)"
        }
    }
    var nativeName: String {
        switch self {
        case .it: return "Italiano"
        case .es: return "Español (España)"
        case .esLatAm: return "Español (América Latina)"
        case .fr: return "Français"
        case .la: return "Latīna"
        case .pt: return "Português (Portugal)"
        case .ptBR: return "Português (Brasil)"
        }
    }
    var hello: String {
        switch self {
        case .it: return "Ciao"
        case .es, .esLatAm: return "Hola"
        case .fr: return "Bonjour"
        case .la: return "Salvē"
        case .pt, .ptBR: return "Olá"
        }
    }
    /// Voice used by AVSpeechSynthesizer. Latin has no system voice; an Italian voice gives an ecclesiastical-style reading.
    var speechLocale: String {
        switch self {
        case .it, .la: return "it-IT"
        case .es: return "es-ES"
        case .esLatAm: return "es-MX"
        case .fr: return "fr-FR"
        case .pt: return "pt-PT"
        case .ptBR: return "pt-BR"
        }
    }
    var engine: LanguageEngine {
        switch self {
        case .it: return ItalianEngine()
        case .es: return SpanishEngine()
        case .esLatAm: return SpanishEngine(code: .esLatAm)
        case .fr: return FrenchEngine()
        case .la: return LatinEngine()
        case .pt: return PortugueseEngine()
        case .ptBR: return PortugueseEngine(code: .ptBR)
        }
    }
    /// Regional pack ids remain separate for persistence; badges stay compact.
    var badge: String {
        switch self {
        case .es, .esLatAm: return "ES"
        case .pt, .ptBR: return "PT"
        default: return rawValue.uppercased()
        }
    }
    var strings: UIStrings { UIStrings.for(self) }
    /// Level labels shown on the onboarding level step.
    var startLevels: [String] { self == .la ? ["I", "II", "III", "IV"] : ["A1", "A2", "B1", "B2"] }
}

// MARK: - Tool model

struct Expr: Identifiable, Equatable, Hashable {
    let label: String
    let text: String
    var id: String { label + "|" + text }
}

typealias ItalianExpression = Expr

enum ToolKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case numbers, prices, time, date, phone, market, years, verbs, numerals, calendar
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .numbers: return "textformat.123"
        case .prices: return "eurosign.circle"
        case .time: return "clock"
        case .date: return "calendar"
        case .phone: return "phone"
        case .market: return "basket"
        case .years: return "building.columns"
        case .verbs: return "text.book.closed"
        case .numerals: return "number"
        case .calendar: return "calendar.badge.clock"
        }
    }
}

struct ToolInput {
    var text = ""
    var mode = ""
    var form = ""
    var hour = 0
    var minute = 0
    var date = Date()
    var unit = "g"
}

struct ToolOutput: Equatable {
    var label: String
    var headline: String
    var sub: String?
    var rows: [Expr]
}

struct ChoiceOption: Identifiable, Hashable {
    let id: String
    let label: String
}

struct ConversionError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

// MARK: - Verbs

struct VerbHint {
    var forms: String? = nil       // Latin principal parts, e.g. "-cēdere -cessī -cessum"
    var verbClass: String? = nil   // Latin class, e.g. "3rd Conjugation -iō", "Deponent"
}

struct ConjugationTense: Identifiable {
    let name: String
    let forms: [String]
    let note: String
    var id: String { name }
}

struct Conjugation {
    let lemma: String
    let kind: String
    let pronouns: [String]
    let tenses: [ConjugationTense]
}

// MARK: - Drills (hear the language, type the digits)

enum AnswerKind: Equatable {
    case digits(String)
    case price(euros: Int, cents: Int)
    case time(hour: Int, minute: Int)
    case dayMonth(day: Int, month: Int)
    case grams(Int)
}

struct DrillItem: Equatable {
    let spoken: String
    let answer: String
    let placeholder: String
    let kind: AnswerKind

    func check(_ input: String) -> Bool {
        let v = input.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .digits(let d):
            if let r = NumberParsing.fromRoman(v) { return String(r) == d }
            return v.filter(\.isNumber) == d
        case .price(let euros, let cents):
            let cleaned = v.filter { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ".", with: ",")
            let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            let a = Int(parts.first ?? "") ?? -1
            let bRaw = parts.count > 1 ? String(parts[1]) : ""
            let b = Int(bRaw.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
            return a == euros && b == cents
        case .time(let hour, let minute):
            let nums = v.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard let hh = nums.first else { return false }
            let mi = nums.count > 1 ? nums[1] : 0
            return mi == minute && (hh == hour || hh == hour % 12 || (hh == 12 && hour % 12 == 0))
        case .dayMonth(let day, let month):
            let nums = v.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            return nums.count >= 2 && nums[0] == day && nums[1] == month
        case .grams(let g):
            guard let n = Double(v.filter { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: ".")),
                  n.isFinite, abs(n) < 1e12 else { return false }
            return Int(n) == g || Int(n * 1000) == g
        }
    }
}

/// Deterministic generator so the daily challenge is the same all day.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Real-life objects shown as cards

struct Realia: Identifiable {
    enum Kind { case receipt, clock, ticket, priceTag, contact, museum, elevator, pharmacy, inscription, calendarStone }
    let id = UUID()
    var kind: Kind
    var question: String
    var answer: String
    var alternative: String?
    var speech: String
    // Drawing payload (meaning depends on kind)
    var title = ""
    var subtitle = ""
    var big = ""
    var lines: [(String, String)] = []
    var footer: (String, String)? = nil
    var hour = 0
    var minute = 0
}

// MARK: - Engine

protocol LanguageEngine {
    var code: LanguageCode { get }
    var tools: [ToolKind] { get }
    func title(_ tool: ToolKind) -> String
    /// Sub-modes for the number tool (cardinal, ordinal, percent…).
    var numberModes: [ChoiceOption] { get }
    var ordinalForms: [ChoiceOption] { get }
    var pronouns: [String] { get }

    /// The headline of the Today clock card: question, main line, second line.
    func clockCard(_ now: Date) -> (question: String, headline: String, line: String)
    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput
    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation?
    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using rng: inout R) -> DrillItem
    func realia<R: RandomNumberGenerator>(using rng: inout R) -> Realia
}

extension LanguageEngine {
    func drill(_ tool: ToolKind) -> DrillItem {
        var g = SystemRandomNumberGenerator()
        return drill(tool, using: &g)
    }
    func realia() -> Realia {
        var g = SystemRandomNumberGenerator()
        return realia(using: &g)
    }
    /// Five items read aloud, the same all day.
    func dailyChallenge(day: Int) -> [DrillItem] {
        var r = SeededRandom(seed: day &* 7919 &+ (LanguageCode.allCases.firstIndex(of: code) ?? 0) &* 31)
        let plan: [ToolKind] = code == .la ? [.numerals, .numerals, .calendar, .years, .numerals] : [.numbers, .numbers, .prices, .time, .years]
        return plan.map { drill($0, using: &r) }
    }
}

// MARK: - Shared helpers

enum NumberParsing {
    struct Parsed {
        var negative: Bool
        var whole: Int
        var fraction: String?
    }

    /// Parses "1.234", "1234,5", "-3" the way a continental European reads them.
    static func parse(_ input: String) throws -> Parsed {
        var s = input.filter { !$0.isWhitespace && $0 != "_" }
        guard !s.isEmpty else { throw ConversionError("Type a number.") }
        var negative = false
        if let first = s.first, first == "-" || first == "+" { negative = first == "-"; s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }) else {
            throw ConversionError("Use digits, an optional minus sign, and one decimal comma or point.")
        }
        let separators = s.filter { $0 == "." || $0 == "," }
        var whole = s
        var fraction: String? = nil
        if separators.count == 1 {
            let idx = s.firstIndex(where: { $0 == "." || $0 == "," })!
            whole = String(s[..<idx])
            let frac = String(s[s.index(after: idx)...])
            guard !frac.isEmpty else { throw ConversionError("Add digits after the decimal separator.") }
            if separators == "." && frac.count == 3 && whole.count >= 1 && whole.count <= 3 { whole += frac } else { fraction = frac }
        } else if separators.count > 1 {
            let lastSep = separators.last!
            let lastIdx = s.lastIndex(of: lastSep)!
            let tail = String(s[s.index(after: lastIdx)...])
            if lastSep != separators.first! || tail.count != 3 {
                whole = String(s[..<lastIdx]).filter { $0.isNumber }
                fraction = tail
            } else {
                whole = s.filter { $0.isNumber }
            }
        }
        while whole.count > 1 && whole.hasPrefix("0") { whole.removeFirst() }
        if whole.isEmpty { whole = "0" }
        guard whole.count <= 15, let w = Int(whole) else { throw ConversionError("Use a whole number up to 999 999 999 999 999.") }
        if let f = fraction, f.count > 6 { throw ConversionError("Use at most six decimal places.") }
        return Parsed(negative: negative, whole: w, fraction: fraction)
    }

    static func cents(_ p: Parsed) throws -> Int {
        guard let f = p.fraction else { return 0 }
        guard f.count <= 2 else { throw ConversionError("Prices have at most two decimal places.") }
        return Int(f.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
    }

    static func euroDisplay(_ whole: Int, _ cents: Int) -> String {
        "€ \(whole.formatted(.number.locale(Locale(identifier: "it_IT")))),\(String(format: "%02d", cents))"
    }

    static func roman(_ value: Int) -> String {
        var n = value, s = ""
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        for (v, r) in table { while n >= v { s += r; n -= v } }
        return s
    }

    /// Strict Roman numeral parser (I–MMMCMXCIX). Returns nil for malformed input.
    static func fromRoman(_ input: String) -> Int? {
        let s = input.uppercased().filter { !$0.isWhitespace }
        guard !s.isEmpty, s.allSatisfy({ "IVXLCDM".contains($0) }) else { return nil }
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000]
        var total = 0
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            let v = values[c]!
            if i + 1 < chars.count, let next = values[chars[i + 1]], next > v { total -= v } else { total += v }
        }
        guard total > 0, total < 4000, roman(total) == s else { return nil }
        return total
    }

    static func groupedDigits(_ input: String, firstGroup: Int, size: Int) -> [String] {
        let digits = Array(input.filter(\.isNumber))
        var groups: [String] = []
        var i = 0
        if firstGroup > 0 && digits.count > firstGroup + 1 {
            groups.append(String(digits[0..<firstGroup])); i = firstGroup
        }
        while i < digits.count {
            let remaining = digits.count - i
            let n = remaining == size + 1 && size == 2 ? 3 : (remaining == 1 ? 1 : min(size, remaining))
            groups.append(String(digits[i..<(i + n)])); i += n
        }
        return groups
    }
}

extension RandomNumberGenerator {
    mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &self) }
    mutating func pick<T>(_ a: [T]) -> T { a[Int.random(in: 0..<a.count, using: &self)] }
    mutating func chance(_ p: Double) -> Bool { Double.random(in: 0..<1, using: &self) < p }
}
