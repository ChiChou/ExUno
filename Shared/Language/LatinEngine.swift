import Foundation

enum LatinNumbers {
    static let units = ["nihil", "ūnus", "duo", "trēs", "quattuor", "quīnque", "sex", "septem", "octō", "novem", "decem",
                        "ūndecim", "duodecim", "tredecim", "quattuordecim", "quīndecim", "sēdecim", "septendecim", "duodēvīgintī", "ūndēvīgintī"]
    static let tens = ["", "decem", "vīgintī", "trīgintā", "quadrāgintā", "quīnquāgintā", "sexāgintā", "septuāgintā", "octōgintā", "nōnāgintā"]
    static let hundreds = ["", "centum", "ducentī", "trecentī", "quadringentī", "quīngentī", "sescentī", "septingentī", "octingentī", "nōngentī"]

    private static func below100(_ n: Int) -> String {
        if n < 20 { return units[n] }
        let t = n / 10, u = n % 10
        if u == 8 && t < 9 { return "duodē" + tens[t + 1] }     // 28 → duodētrīgintā
        if u == 9 && t < 9 { return "ūndē" + tens[t + 1] }      // 29 → ūndētrīgintā
        return tens[t] + (u > 0 ? " " + units[u] : "")
    }
    private static func below1000(_ n: Int) -> String {
        if n < 100 { return below100(n) }
        let h = n / 100, r = n % 100
        return hundreds[h] + (r > 0 ? " " + below100(r) : "")
    }
    /// Cardinal in the nominative masculine, 0–999 999.
    static func cardinal(_ n: Int) throws -> String {
        guard (0...999_999).contains(n) else { throw ConversionError("Use a number from 0 to 999 999.") }
        if n < 1000 { return below1000(n) }
        let th = n / 1000, r = n % 1000
        let head = th == 1 ? "mīlle" : (th == 2 ? "duo" : th == 3 ? "tria" : below1000(th)) + " mīlia"
        return head + (r > 0 ? " " + below1000(r) : "")
    }

    private static let ordUnits = ["", "prīmus", "secundus", "tertius", "quārtus", "quīntus", "sextus", "septimus", "octāvus", "nōnus"]
    private static let ordTens = ["", "decimus", "vīcēsimus", "trīcēsimus", "quadrāgēsimus", "quīnquāgēsimus", "sexāgēsimus", "septuāgēsimus", "octōgēsimus", "nōnāgēsimus"]
    private static let ordHundreds = ["", "centēsimus", "ducentēsimus", "trecentēsimus", "quadringentēsimus", "quīngentēsimus", "sescentēsimus", "septingentēsimus", "octingentēsimus", "nōngentēsimus"]

    /// Ordinal, nominative masculine; `form` "a" gives feminine, "um" neuter, "acc" accusative masculine (calendar use).
    static func ordinal(_ n: Int, form: String = "us") throws -> String {
        guard (1...3999).contains(n) else { throw ConversionError("Use a number from 1 to 3999.") }
        var parts: [String] = []
        if n >= 1000 { parts.append(n / 1000 == 1 ? "mīllēsimus" : (try cardinalAdverbThousands(n / 1000)) + " mīllēsimus") }
        let h = (n % 1000) / 100, rest = n % 100
        if h > 0 { parts.append(ordHundreds[h]) }
        if rest > 0 {
            let t = rest / 10, u = rest % 10
            if rest == 11 { parts.append("ūndecimus") }
            else if rest == 12 { parts.append("duodecimus") }
            else if u == 8 && t >= 1 && t < 9 { parts.append("duodē" + ordTens[t + 1]) }
            else if u == 9 && t >= 1 && t < 9 { parts.append("ūndē" + ordTens[t + 1]) }
            else if t == 1 { parts.append(ordUnits[u] + " decimus") }
            else {
                if t > 0 { parts.append(ordTens[t]) }
                if u > 0 { parts.append(ordUnits[u]) }
            }
        }
        let base = parts.joined(separator: " ")
        guard form != "us" else { return base }
        let suffix: String = ["a": "a", "um": "um", "acc": "um", "abl": "ō"][form] ?? "us"
        return base.split(separator: " ").map { w -> String in
            let s = String(w)
            return s.hasSuffix("us") ? String(s.dropLast(2)) + suffix : s
        }.joined(separator: " ")
    }
    private static func cardinalAdverbThousands(_ n: Int) throws -> String {
        ["", "", "bis", "ter"][n]
    }
}

enum RomanCalendar {
    static let monthAcc = ["Iānuāriās", "Februāriās", "Mārtiās", "Aprīlēs", "Māiās", "Iūniās", "Iūliās", "Augustās", "Septembrēs", "Octōbrēs", "Novembrēs", "Decembrēs"]
    static let monthAbl = ["Iānuāriīs", "Februāriīs", "Mārtiīs", "Aprīlibus", "Māiīs", "Iūniīs", "Iūliīs", "Augustīs", "Septembribus", "Octōbribus", "Novembribus", "Decembribus"]
    static let monthAbbr = ["Ian.", "Feb.", "Mart.", "Apr.", "Mai.", "Iun.", "Iul.", "Aug.", "Sept.", "Oct.", "Nov.", "Dec."]
    static let weekdays = ["diēs Sōlis", "diēs Lūnae", "diēs Mārtis", "diēs Mercuriī", "diēs Iovis", "diēs Veneris", "diēs Saturnī"]

    struct RomanDate { var full: String; var abbreviated: String; var numeral: Int?; var anchor: String }

    static func nones(_ month: Int) -> Int { [3, 5, 7, 10].contains(month) ? 7 : 5 }   // March, May, July, October
    static func ides(_ month: Int) -> Int { nones(month) + 8 }

    /// Converts a Julian-style reckoning onto the given (Gregorian) date: counts are inclusive.
    static func date(day: Int, month: Int, year: Int) -> RomanDate {
        let calendar = Calendar(identifier: .gregorian)
        let daysInMonth = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!)!.count
        let leap = daysInMonth == 29 && month == 2
        let n = nones(month), i = ides(month)
        func before(_ count: Int, _ anchorAcc: String, _ abbr: String, monthIndex: Int, bis: Bool = false) -> RomanDate {
            if count == 2 { return RomanDate(full: "prīdiē \(anchorAcc) \(monthAcc[monthIndex])", abbreviated: "prid. \(abbr) \(monthAbbr[monthIndex])", numeral: nil, anchor: abbr) }
            let ord = (try? LatinNumbers.ordinal(count, form: "acc")) ?? "\(count)"
            let b = bis ? "bis " : ""
            return RomanDate(full: "ante diem \(b)\(ord) \(anchorAcc) \(monthAcc[monthIndex])", abbreviated: "a.d. \(b)\(NumberParsing.roman(count)) \(abbr) \(monthAbbr[monthIndex])", numeral: count, anchor: abbr)
        }
        let m = month - 1
        if day == 1 { return RomanDate(full: "Kalendīs \(monthAbl[m])", abbreviated: "Kal. \(monthAbbr[m])", numeral: nil, anchor: "Kal.") }
        if day < n { return before(n - day + 1, "Nōnās", "Non.", monthIndex: m) }
        if day == n { return RomanDate(full: "Nōnīs \(monthAbl[m])", abbreviated: "Non. \(monthAbbr[m])", numeral: nil, anchor: "Non.") }
        if day < i { return before(i - day + 1, "Īdūs", "Id.", monthIndex: m) }
        if day == i { return RomanDate(full: "Īdibus \(monthAbl[m])", abbreviated: "Id. \(monthAbbr[m])", numeral: nil, anchor: "Id.") }
        let next = (m + 1) % 12
        if leap && day >= 24 {
            // Leap day: 24 and 25 Feb are both "the sixth before the Kalends of March".
            if day == 24 { return before(6, "Kalendās", "Kal.", monthIndex: next) }
            if day == 25 { return before(6, "Kalendās", "Kal.", monthIndex: next, bis: true) }
            return before(28 - (day - 1) + 2, "Kalendās", "Kal.", monthIndex: next)
        }
        return before(daysInMonth - day + 2, "Kalendās", "Kal.", monthIndex: next)
    }
}

struct LatinEngine: LanguageEngine {
    let code = LanguageCode.la
    let tools: [ToolKind] = [.numerals, .calendar, .years, .verbs]
    let pronouns = ["ego", "tū", "is / ea", "nōs", "vōs", "eī / eae"]

    func title(_ tool: ToolKind) -> String {
        switch tool {
        case .numerals, .numbers: return "Numerī"
        case .calendar, .date: return "Calendārium"
        case .years: return "Annī"
        case .verbs: return "Verba"
        case .prices: return "Pretia"
        case .time: return "Hōra"
        case .phone: return "Numerus"
        case .market: return "Forum"
        }
    }
    var numberModes: [ChoiceOption] { [ChoiceOption(id: "number", label: "Cardinālis"), ChoiceOption(id: "ordinal", label: "Ōrdinālis")] }
    var ordinalForms: [ChoiceOption] { [ChoiceOption(id: "us", label: "-us"), ChoiceOption(id: "a", label: "-a"), ChoiceOption(id: "um", label: "-um")] }

    func clockCard(_ now: Date) -> (question: String, headline: String, line: String) {
        let c = Calendar.current.dateComponents([.day, .month, .year, .weekday], from: now)
        let rd = RomanCalendar.date(day: c.day ?? 1, month: c.month ?? 1, year: c.year ?? 2026)
        let y = c.year ?? 2026
        return ("Quis diēs est?", rd.full, "\(RomanCalendar.weekdays[(c.weekday ?? 1) - 1]) · \(NumberParsing.roman(y)) · \(NumberParsing.roman(y + 753)) a.u.c.")
    }

    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput {
        let v = input.text.trimmingCharacters(in: .whitespaces)
        switch tool {
        case .numerals, .numbers:
            let n: Int
            if let r = NumberParsing.fromRoman(v) { n = r }
            else if let d = Int(v.filter(\.isNumber)), !v.isEmpty, v.allSatisfy({ $0.isNumber || $0 == "." || $0 == " " }) { n = d }
            else { throw ConversionError("Type digits (2026) or a Roman numeral (MMXXVI).") }
            if input.mode == "ordinal" {
                return ToolOutput(label: "Ōrdinālis", headline: try LatinNumbers.ordinal(n, form: input.form.isEmpty ? "us" : input.form), sub: "\(n) · \(n < 4000 ? NumberParsing.roman(n) : "")", rows: [
                    Expr(label: "Cardinālis", text: try LatinNumbers.cardinal(n))])
            }
            var rows: [Expr] = []
            if (1...3999).contains(n) {
                rows.append(Expr(label: "Numerus Rōmānus", text: NumberParsing.roman(n)))
                rows.append(Expr(label: "Ōrdinālis", text: try LatinNumbers.ordinal(n)))
            }
            return ToolOutput(label: "Latīnē", headline: try LatinNumbers.cardinal(n), sub: "\(n)", rows: rows)
        case .calendar, .date:
            let c = Calendar.current.dateComponents([.day, .month, .year, .weekday], from: input.date)
            let rd = RomanCalendar.date(day: c.day ?? 1, month: c.month ?? 1, year: c.year ?? 2026)
            let y = c.year ?? 2026
            return ToolOutput(label: "Quis diēs est?", headline: rd.full, sub: rd.abbreviated, rows: [
                Expr(label: "Diēs hebdomadis", text: RomanCalendar.weekdays[(c.weekday ?? 1) - 1]),
                Expr(label: "Annō Dominī", text: "annō Dominī \(NumberParsing.roman(y))"),
                Expr(label: "Ab urbe conditā", text: "\(NumberParsing.roman(y + 753)) a.u.c.")])
        case .years:
            let y: Int
            if let r = NumberParsing.fromRoman(v) { y = r } else if let d = Int(v.filter(\.isNumber)) { y = d } else { throw ConversionError("Type a year.") }
            guard (1...3246).contains(y) else { throw ConversionError("Use a year from 1 to 3246.") }
            let auc = y + 753
            var rows = [Expr(label: "Numerus Rōmānus", text: NumberParsing.roman(y)),
                        Expr(label: "Annō…", text: "annō \(try LatinNumbers.ordinal(y, form: "abl"))"),
                        Expr(label: "Saeculum", text: "saeculum \(NumberParsing.roman((y - 1) / 100 + 1))")]
            if auc < 4000 { rows.append(Expr(label: "Ab urbe conditā", text: "\(NumberParsing.roman(auc)) a.u.c.")) }
            return ToolOutput(label: "Annus", headline: try LatinNumbers.cardinal(y), sub: "\(y)", rows: rows)
        default:
            throw ConversionError("This tool isn't available in Latin.")
        }
    }

    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation? { LatinConjugator.conjugate(verb, hint: hint, pronouns: pronouns) }

    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using r: inout R) -> DrillItem {
        switch tool {
        case .calendar, .date:
            let month = r.int(1...12), day = r.int(1...28)
            let rd = RomanCalendar.date(day: day, month: month, year: 2026)
            return DrillItem(spoken: rd.full, answer: "\(day)/\(month)", placeholder: "15/3", kind: .dayMonth(day: day, month: month))
        case .years:
            let y = r.int(1...2026)
            return DrillItem(spoken: (try? LatinNumbers.cardinal(y)) ?? "", answer: "\(y) · \(NumberParsing.roman(y))", placeholder: "753", kind: .digits("\(y)"))
        default:
            let n = r.chance(0.5) ? r.int(1...30) : r.int(31...999)
            return DrillItem(spoken: (try? LatinNumbers.cardinal(n)) ?? "", answer: "\(n) · \(NumberParsing.roman(n))", placeholder: "XXIX", kind: .digits("\(n)"))
        }
    }

    private static let inscriptions: [(String, String, Int)] = [
        ("PANTHEON", "M·AGRIPPA·L·F·COS·TERTIVM·FECIT", 27), ("COLOSSEVM", "AMPHITHEATRVM FLAVIVM", 80), ("ARCVS TITI", "SENATVS POPVLVSQVE ROMANVS", 81),
        ("BASILICA", "ANNO IVBILAEI", 1300), ("FONS TREVI", "AQVA VIRGO", 1762), ("PORTA", "ANNO DOMINI", 1585), ("HOROLOGIVM", "TEMPVS FVGIT", 1650)]

    func realia<R: RandomNumberGenerator>(using r: inout R) -> Realia {
        if r.chance(0.5) {
            let month = r.int(1...12), day = r.int(1...28)
            let rd = RomanCalendar.date(day: day, month: month, year: 2026)
            var x = Realia(kind: .calendarStone, question: "Quis diēs est?", answer: rd.full, alternative: "\(day). \(month).", speech: rd.full)
            x.title = rd.abbreviated.uppercased().replacingOccurrences(of: ".", with: "·"); x.big = "\(day) · \(month)"
            return x
        }
        let (title, line, year) = r.pick(Self.inscriptions)
        let shift = r.int(0...30)
        let y = year + shift
        var x = Realia(kind: .inscription, question: "Quō annō?", answer: "annō \((try? LatinNumbers.ordinal(y, form: "abl")) ?? "")", alternative: "\(y) · \((try? LatinNumbers.cardinal(y)) ?? "")", speech: "annō \((try? LatinNumbers.ordinal(y, form: "abl")) ?? "")")
        x.title = title; x.subtitle = line; x.big = NumberParsing.roman(y)
        return x
    }
}

// MARK: - Conjugation (active indicative for regular verbs, deponents and the common irregulars)

enum LatinConjugator {
    private static let irregular: [String: [(String, [String])]] = [
        "sum": [("Praesēns", ["sum", "es", "est", "sumus", "estis", "sunt"]), ("Imperfectum", ["eram", "erās", "erat", "erāmus", "erātis", "erant"]),
                ("Futūrum", ["erō", "eris", "erit", "erimus", "eritis", "erunt"]), ("Perfectum", ["fuī", "fuistī", "fuit", "fuimus", "fuistis", "fuērunt"])],
        "possum": [("Praesēns", ["possum", "potes", "potest", "possumus", "potestis", "possunt"]), ("Imperfectum", ["poteram", "poterās", "poterat", "poterāmus", "poterātis", "poterant"]),
                   ("Futūrum", ["poterō", "poteris", "poterit", "poterimus", "poteritis", "poterunt"]), ("Perfectum", ["potuī", "potuistī", "potuit", "potuimus", "potuistis", "potuērunt"])],
        "eō": [("Praesēns", ["eō", "īs", "it", "īmus", "ītis", "eunt"]), ("Imperfectum", ["ībam", "ībās", "ībat", "ībāmus", "ībātis", "ībant"]),
               ("Futūrum", ["ībō", "ībis", "ībit", "ībimus", "ībitis", "ībunt"]), ("Perfectum", ["iī", "īstī", "iit", "iimus", "īstis", "iērunt"])],
        "ferō": [("Praesēns", ["ferō", "fers", "fert", "ferimus", "fertis", "ferunt"]), ("Imperfectum", ["ferēbam", "ferēbās", "ferēbat", "ferēbāmus", "ferēbātis", "ferēbant"]),
                 ("Futūrum", ["feram", "ferēs", "feret", "ferēmus", "ferētis", "ferent"]), ("Perfectum", ["tulī", "tulistī", "tulit", "tulimus", "tulistis", "tulērunt"])],
        "volō": [("Praesēns", ["volō", "vīs", "vult", "volumus", "vultis", "volunt"]), ("Imperfectum", ["volēbam", "volēbās", "volēbat", "volēbāmus", "volēbātis", "volēbant"]),
                 ("Futūrum", ["volam", "volēs", "volet", "volēmus", "volētis", "volent"]), ("Perfectum", ["voluī", "voluistī", "voluit", "voluimus", "voluistis", "voluērunt"])],
        "nōlō": [("Praesēns", ["nōlō", "nōn vīs", "nōn vult", "nōlumus", "nōn vultis", "nōlunt"]), ("Imperfectum", ["nōlēbam", "nōlēbās", "nōlēbat", "nōlēbāmus", "nōlēbātis", "nōlēbant"]),
                 ("Futūrum", ["nōlam", "nōlēs", "nōlet", "nōlēmus", "nōlētis", "nōlent"]), ("Perfectum", ["nōluī", "nōluistī", "nōluit", "nōluimus", "nōluistis", "nōluērunt"])],
        "mālō": [("Praesēns", ["mālō", "māvīs", "māvult", "mālumus", "māvultis", "mālunt"]), ("Imperfectum", ["mālēbam", "mālēbās", "mālēbat", "mālēbāmus", "mālēbātis", "mālēbant"]),
                 ("Futūrum", ["mālam", "mālēs", "mālet", "mālēmus", "mālētis", "mālent"]), ("Perfectum", ["māluī", "māluistī", "māluit", "māluimus", "māluistis", "māluērunt"])],
        "fīō": [("Praesēns", ["fīō", "fīs", "fit", "fīmus", "fītis", "fīunt"]), ("Imperfectum", ["fīēbam", "fīēbās", "fīēbat", "fīēbāmus", "fīēbātis", "fīēbant"]),
                ("Futūrum", ["fīam", "fīēs", "fīet", "fīēmus", "fīētis", "fīent"]), ("Perfectum", ["factus sum", "factus es", "factus est", "factī sumus", "factī estis", "factī sunt"])],
        "dō": [("Praesēns", ["dō", "dās", "dat", "damus", "datis", "dant"]), ("Imperfectum", ["dabam", "dabās", "dabat", "dabāmus", "dabātis", "dabant"]),
               ("Futūrum", ["dabō", "dabis", "dabit", "dabimus", "dabitis", "dabunt"]), ("Perfectum", ["dedī", "dedistī", "dedit", "dedimus", "dedistis", "dedērunt"])]
    ]
    /// Compounds of sum, eō and ferō conjugate like their base.
    private static let compounds: [(prefix: String, base: String)] = [
        ("ab", "sum"), ("ad", "sum"), ("dē", "sum"), ("prae", "sum"), ("prō", "sum"), ("inter", "sum"), ("ob", "sum"), ("sub", "sum"), ("super", "sum"),
        ("ab", "eō"), ("ad", "eō"), ("ex", "eō"), ("red", "eō"), ("trāns", "eō"), ("per", "eō"), ("prae", "eō"), ("sub", "eō"), ("inter", "eō"), ("ob", "eō"), ("in", "eō"), ("prōd", "eō")]

    private static func strip(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "la")).lowercased()
    }

    static func conjugate(_ input: String, hint: VerbHint?, pronouns: [String]) -> Conjugation? {
        let lemma = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !lemma.isEmpty else { return nil }
        if let table = irregular.first(where: { strip($0.key) == strip(lemma) }) {
            return Conjugation(lemma: table.key, kind: "Verbum irrēgulāre", pronouns: pronouns, tenses: table.value.map { ConjugationTense(name: $0.0, forms: $0.1, note: "irrēgulāre") })
        }
        let parts = (hint?.forms ?? "").replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ":", with: " ")
            .split(separator: " ").map(String.init)
        if let c = compounds.first(where: { strip($0.prefix + $0.base) == strip(lemma) }) {
            let tenses = irregular[c.base]!.map { name, forms in
                ConjugationTense(name: name, forms: forms.map { f in
                    if c.prefix == "ab" && f.hasPrefix("f") { return "ā" + f }
                    if c.prefix == "prō" && c.base == "sum" && f.hasPrefix("e") { return "prōd" + f }
                    return c.prefix + f
                }, note: "ut \(c.base)")
            }
            return Conjugation(lemma: lemma, kind: "Verbum compositum", pronouns: pronouns, tenses: tenses)
        }
        if strip(lemma).hasSuffix("fero"), lemma.count > 4 {
            let prefix = String(lemma.dropLast(4))
            var tenses = irregular["ferō"]!.prefix(3).map { name, forms in ConjugationTense(name: name, forms: forms.map { prefix + $0 }, note: "ut ferō") }
            if parts.count >= 2, let perf = resolve(parts[1], lemma: lemma, stem: prefix), perf.hasSuffix("ī") {
                let ps = String(perf.dropLast())
                tenses.append(ConjugationTense(name: "Perfectum", forms: ["ī", "istī", "it", "imus", "istis", "ērunt"].map { ps + $0 }, note: perf))
            }
            return Conjugation(lemma: lemma, kind: "Verbum compositum", pronouns: pronouns, tenses: tenses)
        }
        guard let cls = hint?.verbClass else { return regularGuess(lemma, pronouns: pronouns) }
        if cls.contains("Deponent") {
            let stem = String(lemma.dropLast(lemma.hasSuffix("eor") || lemma.hasSuffix("ior") ? 3 : 2))
            let inf = parts.first.flatMap { resolve($0, lemma: lemma, stem: stem) } ?? ""
            let part = parts.count > 1 ? resolve(parts[1], lemma: lemma, stem: stem) : nil
            return deponent(lemma, infinitive: inf, participle: part, pronouns: pronouns)
        }
        let conj: Int
        if cls.hasPrefix("1st") { conj = 1 } else if cls.hasPrefix("2nd") { conj = 2 } else if cls.contains("-iō") { conj = 5 } else if cls.hasPrefix("3rd") { conj = 3 } else if cls.hasPrefix("4th") { conj = 4 }
        else { return regularGuess(lemma, pronouns: pronouns) }
        let stem = presentStem(lemma, conj: conj)
        let perfect = parts.count > 1 ? resolve(parts[1], lemma: lemma, stem: stem) : nil
        return build(lemma, conj: conj, perfect: perfect, pronouns: pronouns)
    }

    private static func presentStem(_ lemma: String, conj: Int) -> String {
        switch conj {
        case 2, 4, 5: return String(lemma.dropLast(2))   // moneō, audiō, capiō
        default: return String(lemma.dropLast())          // amō, regō
        }
    }

    /// DCC abbreviates principal parts ("-cēdere", "-uī"). Vowel-initial endings attach to the present stem;
    /// consonant-initial ones overlap the lemma at the last matching letter (accēdō + -cessī → accessī).
    private static func resolve(_ part: String, lemma: String, stem: String) -> String? {
        guard !part.isEmpty else { return nil }
        guard part.hasPrefix("-") else { return part }
        let p = String(part.dropFirst())
        guard let first = p.first else { return nil }
        if "aeiou".contains(strip(String(first))) { return stem + p }
        let lc = Array(lemma)
        for cut in stride(from: lc.count - 1, through: 1, by: -1) where strip(String(lc[cut])) == strip(String(first)) {
            return String(lc[0..<cut]) + p
        }
        return stem + p
    }

    private static func build(_ lemma: String, conj: Int, perfect: String?, pronouns: [String]) -> Conjugation {
        let stem = presentStem(lemma, conj: conj)
        let present: [String], imperfect: [String], future: [String]
        switch conj {
        case 1:
            present = [lemma, stem + "ās", stem + "at", stem + "āmus", stem + "ātis", stem + "ant"]
            imperfect = ["ābam", "ābās", "ābat", "ābāmus", "ābātis", "ābant"].map { stem + $0 }
            future = ["ābō", "ābis", "ābit", "ābimus", "ābitis", "ābunt"].map { stem + $0 }
        case 2:
            present = [lemma, stem + "ēs", stem + "et", stem + "ēmus", stem + "ētis", stem + "ent"]
            imperfect = ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"].map { stem + $0 }
            future = ["ēbō", "ēbis", "ēbit", "ēbimus", "ēbitis", "ēbunt"].map { stem + $0 }
        case 3:
            present = [lemma, stem + "is", stem + "it", stem + "imus", stem + "itis", stem + "unt"]
            imperfect = ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"].map { stem + $0 }
            future = ["am", "ēs", "et", "ēmus", "ētis", "ent"].map { stem + $0 }
        case 5:
            present = [lemma, stem + "is", stem + "it", stem + "imus", stem + "itis", stem + "iunt"]
            imperfect = ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"].map { stem + $0 }
            future = ["iam", "iēs", "iet", "iēmus", "iētis", "ient"].map { stem + $0 }
        default:
            present = [lemma, stem + "īs", stem + "it", stem + "īmus", stem + "ītis", stem + "iunt"]
            imperfect = ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"].map { stem + $0 }
            future = ["iam", "iēs", "iet", "iēmus", "iētis", "ient"].map { stem + $0 }
        }
        var tenses = [ConjugationTense(name: "Praesēns", forms: present, note: conjName(conj)),
                      ConjugationTense(name: "Imperfectum", forms: imperfect, note: ""),
                      ConjugationTense(name: "Futūrum", forms: future, note: conj <= 2 ? "-bō, -bis" : "-am, -ēs")]
        if let p = perfect, p.hasSuffix("ī") {
            let ps = String(p.dropLast())
            tenses.append(ConjugationTense(name: "Perfectum", forms: ["ī", "istī", "it", "imus", "istis", "ērunt"].map { ps + $0 }, note: "\(p)"))
        }
        return Conjugation(lemma: lemma, kind: "Coniugātiō \(conjName(conj))", pronouns: pronouns, tenses: tenses)
    }

    private static func deponent(_ lemma: String, infinitive: String, participle: String?, pronouns: [String]) -> Conjugation? {
        // hortor hortārī, vereor verērī, sequor sequī, patior patī, orior orīrī
        let tenses: [ConjugationTense]
        if infinitive.hasSuffix("ārī") {
            let s = String(infinitive.dropLast(3))
            tenses = [ConjugationTense(name: "Praesēns", forms: [lemma, s + "āris", s + "ātur", s + "āmur", s + "āminī", s + "antur"], note: "dēpōnēns"),
                      ConjugationTense(name: "Imperfectum", forms: ["ābar", "ābāris", "ābātur", "ābāmur", "ābāminī", "ābantur"].map { s + $0 }, note: ""),
                      ConjugationTense(name: "Futūrum", forms: ["ābor", "āberis", "ābitur", "ābimur", "ābiminī", "ābuntur"].map { s + $0 }, note: "")]
        } else if infinitive.hasSuffix("ērī") {
            let s = String(infinitive.dropLast(3))
            tenses = [ConjugationTense(name: "Praesēns", forms: [lemma, s + "ēris", s + "ētur", s + "ēmur", s + "ēminī", s + "entur"], note: "dēpōnēns"),
                      ConjugationTense(name: "Imperfectum", forms: ["ēbar", "ēbāris", "ēbātur", "ēbāmur", "ēbāminī", "ēbantur"].map { s + $0 }, note: ""),
                      ConjugationTense(name: "Futūrum", forms: ["ēbor", "ēberis", "ēbitur", "ēbimur", "ēbiminī", "ēbuntur"].map { s + $0 }, note: "")]
        } else if infinitive.hasSuffix("īrī") {
            let s = String(infinitive.dropLast(3))
            tenses = [ConjugationTense(name: "Praesēns", forms: [lemma, s + "īris", s + "ītur", s + "īmur", s + "īminī", s + "iuntur"], note: "dēpōnēns"),
                      ConjugationTense(name: "Imperfectum", forms: ["iēbar", "iēbāris", "iēbātur", "iēbāmur", "iēbāminī", "iēbantur"].map { s + $0 }, note: ""),
                      ConjugationTense(name: "Futūrum", forms: ["iar", "iēris", "iētur", "iēmur", "iēminī", "ientur"].map { s + $0 }, note: "")]
        } else if infinitive.hasSuffix("ī") {
            let io = lemma.hasSuffix("ior")
            let s = String(lemma.dropLast(io ? 3 : 2))
            tenses = [ConjugationTense(name: "Praesēns", forms: [lemma, s + "eris", s + "itur", s + "imur", s + "iminī", s + (io ? "iuntur" : "untur")], note: "dēpōnēns"),
                      ConjugationTense(name: "Imperfectum", forms: ["ēbar", "ēbāris", "ēbātur", "ēbāmur", "ēbāminī", "ēbantur"].map { s + (io ? "i" : "") + $0 }, note: ""),
                      ConjugationTense(name: "Futūrum", forms: ["ar", "ēris", "ētur", "ēmur", "ēminī", "entur"].map { s + (io ? "i" : "") + $0 }, note: "")]
        } else { return nil }
        var all = tenses
        if let p = participle, p.hasSuffix("us") {
            let pl = String(p.dropLast(2)) + "ī"
            all.append(ConjugationTense(name: "Perfectum", forms: ["\(p) sum", "\(p) es", "\(p) est", "\(pl) sumus", "\(pl) estis", "\(pl) sunt"], note: p))
        }
        return Conjugation(lemma: lemma, kind: "Verbum dēpōnēns", pronouns: pronouns, tenses: all)
    }

    /// No dictionary hint: guess the conjugation from the first-person ending.
    private static func regularGuess(_ lemma: String, pronouns: [String]) -> Conjugation? {
        let s = strip(lemma)
        if s.hasSuffix("eo") { return build(lemma, conj: 2, perfect: nil, pronouns: pronouns) }
        if s.hasSuffix("io") { return build(lemma, conj: 4, perfect: nil, pronouns: pronouns) }
        if s.hasSuffix("o") && s.count >= 3 { return build(lemma, conj: 1, perfect: nil, pronouns: pronouns) }
        return nil
    }

    private static func conjName(_ c: Int) -> String {
        switch c { case 1: return "prīma"; case 2: return "secunda"; case 3: return "tertia"; case 5: return "tertia (-iō)"; default: return "quārta" }
    }
}
