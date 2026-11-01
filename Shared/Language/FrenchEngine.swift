import Foundation

/// French, traditional spelling (hyphens below 100, "et" in 21–71), France usage.
enum FrenchNumbers {
    static let units = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix",
                        "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"]
    static let tens = ["", "dix", "vingt", "trente", "quarante", "cinquante", "soixante"]

    /// `final` = the number ends here (so "quatre-vingts" and "deux cents" keep their s).
    private static func below100(_ n: Int, final: Bool = true) -> String {
        if n < 20 { return units[n] }
        let t = n / 10, u = n % 10
        switch t {
        case 7: return u == 1 ? "soixante et onze" : "soixante-" + units[10 + u]
        case 8: return u == 0 ? (final ? "quatre-vingts" : "quatre-vingt") : "quatre-vingt-" + units[u]
        case 9: return "quatre-vingt-" + units[10 + u]
        default:
            if u == 0 { return tens[t] }
            if u == 1 { return tens[t] + " et un" }
            return tens[t] + "-" + units[u]
        }
    }
    private static func below1000(_ n: Int, final: Bool = true) -> String {
        if n < 100 { return below100(n, final: final) }
        let h = n / 100, r = n % 100
        let head = h == 1 ? "cent" : units[h] + " cent" + (r == 0 && final ? "s" : "")
        return head + (r > 0 ? " " + below100(r, final: final) : "")
    }

    static func integer(_ value: Int) -> String {
        if value < 0 { return "moins " + integer(-value) }
        if value < 1000 { return below1000(value) }
        if value < 1_000_000 {
            let th = value / 1000, r = value % 1000
            let head = th == 1 ? "mille" : below1000(th, final: false) + " mille"
            return head + (r > 0 ? " " + below1000(r) : "")
        }
        if value < 1_000_000_000 {
            let mn = value / 1_000_000, r = value % 1_000_000
            let head = mn == 1 ? "un million" : below1000(mn) + " millions"
            return head + (r > 0 ? " " + integer(r) : "")
        }
        let bn = value / 1_000_000_000, r = value % 1_000_000_000
        let head = bn == 1 ? "un milliard" : integer(bn) + " milliards"
        return head + (r > 0 ? " " + integer(r) : "")
    }

    /// Belgian and Swiss forms for 70/80/90 (septante, huitante, nonante).
    static func swiss(_ value: Int) -> String? {
        let tail = value % 100
        guard (70...99).contains(tail) else { return nil }
        let t = tail / 10, u = tail % 10
        let word = ["septante", "huitante", "nonante"][t - 7]
        let low = u == 0 ? word : u == 1 ? word + " et un" : word + "-" + units[u]
        let head = value - tail
        return head == 0 ? low : integer(head) + " " + low
    }

    static func number(_ input: String) throws -> String {
        let p = try NumberParsing.parse(input)
        var out = integer(p.whole)
        if let f = p.fraction {
            if f.hasPrefix("0") || f.count > 3 { out += " virgule " + f.compactMap(\.wholeNumberValue).map { units[$0] }.joined(separator: " ") }
            else { out += " virgule " + integer(Int(f) ?? 0) }
        }
        let nonzero = p.whole != 0 || (p.fraction?.contains { $0 != "0" } ?? false)
        return (p.negative && nonzero ? "moins " : "") + out
    }

    static func ordinal(_ n: Int, feminine: Bool = false) throws -> String {
        guard (1...999_999).contains(n) else { throw ConversionError("Use a number from 1 to 999 999.") }
        if n == 1 { return feminine ? "première" : "premier" }
        var c = integer(n)
        if c.hasSuffix("s") && (c.hasSuffix("cents") || c.hasSuffix("vingts")) { c.removeLast() }
        if c.hasSuffix("cinq") { return c + "uième" }
        if c.hasSuffix("neuf") { return String(c.dropLast()) + "vième" }
        if c.hasSuffix("e") { c.removeLast() }
        return c + "ième"
    }
}

enum FrenchTime {
    static let weekdays = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
    static let months = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

    private static func hourPhrase(_ h: Int) -> String {
        let hh = ((h % 24) + 24) % 24
        if hh == 0 { return "minuit" }
        if hh == 12 { return "midi" }
        let h12 = hh % 12
        return h12 == 1 ? "une heure" : FrenchNumbers.integer(h12) + " heures"
    }
    static func expressions(hour: Int, minute: Int) -> [Expr] {
        var out: [Expr] = []
        func push(_ l: String, _ t: String) { if !out.contains(where: { $0.text == t }) { out.append(Expr(label: l, text: t)) } }
        let next = hourPhrase(hour + 1)
        let cur = hourPhrase(hour)
        let noon = cur == "midi" || cur == "minuit"
        let everyday: String
        switch minute {
        case 0: everyday = "Il est \(cur)\(noon ? "" : " pile")"
        case 15: everyday = "Il est \(cur) et quart"
        case 30: everyday = "Il est \(cur) et \(noon ? "demi" : "demie")"
        case 45: everyday = "Il est \(next) moins le quart"
        case 35...59: everyday = "Il est \(next) moins \(FrenchNumbers.integer(60 - minute))"
        default: everyday = "Il est \(cur) \(FrenchNumbers.integer(minute))"
        }
        push("Courant", everyday)
        let h24 = ((hour % 24) + 24) % 24
        let official = "Il est \(h24 == 1 ? "une heure" : FrenchNumbers.integer(h24) + " heures")\(minute > 0 ? " " + FrenchNumbers.integer(minute) : "")"
        push("Heure officielle", official)
        push("À quelle heure ?", "On se voit à " + everyday.replacingOccurrences(of: "Il est ", with: "").replacingOccurrences(of: " pile", with: ""))
        return out
    }
    static func everyday(hour: Int, minute: Int) -> String { expressions(hour: hour, minute: minute)[0].text }

    struct DateWords { var full: String; var short: String; var withYear: String; var numeric: String; var written: String; var weekday: String }
    static func date(_ d: Date, calendar: Calendar = .current) -> DateWords {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: d)
        let day = c.day ?? 1, month = months[(c.month ?? 1) - 1], year = c.year ?? 2000
        let wd = weekdays[(c.weekday ?? 1) - 1]
        let dayWord = day == 1 ? "premier" : FrenchNumbers.integer(day)
        let yearWord = FrenchNumbers.integer(year)
        return DateWords(full: "\(wd) \(dayWord) \(month) \(yearWord)", short: "le \(dayWord) \(month)", withYear: "le \(dayWord) \(month) \(yearWord)",
                         numeric: String(format: "%02d/%02d/%d", day, c.month ?? 1, year), written: "\(day == 1 ? "1er" : String(day)) \(month) \(year)", weekday: wd)
    }
}

struct FrenchEngine: LanguageEngine {
    let code = LanguageCode.fr
    let tools: [ToolKind] = [.numbers, .prices, .time, .date, .phone, .market, .years, .verbs]
    let pronouns = ["je", "tu", "il / elle", "nous", "vous", "ils / elles"]

    func title(_ tool: ToolKind) -> String {
        switch tool {
        case .numbers, .numerals: return "Nombres"
        case .prices: return "Prix"
        case .time: return "Heure"
        case .date, .calendar: return "Date"
        case .phone: return "Téléphone"
        case .market: return "Au marché"
        case .years: return "Années et siècles"
        case .verbs: return "Verbes"
        }
    }
    var numberModes: [ChoiceOption] {
        [ChoiceOption(id: "number", label: "Nombre"), ChoiceOption(id: "ordinal", label: "Ordinal"), ChoiceOption(id: "percent", label: "Pourcentage"),
         ChoiceOption(id: "degrees", label: "Degrés"), ChoiceOption(id: "floor", label: "Étage")]
    }
    var ordinalForms: [ChoiceOption] { [ChoiceOption(id: "m", label: "le premier"), ChoiceOption(id: "f", label: "la première")] }

    func clockCard(_ now: Date) -> (question: String, headline: String, line: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return ("Quelle heure est-il ?", FrenchTime.everyday(hour: c.hour ?? 0, minute: c.minute ?? 0), "Nous sommes " + FrenchTime.date(now).full)
    }

    static func price(_ input: String) throws -> (spoken: String, formal: String, display: String, euros: Int, cents: Int) {
        let p = try NumberParsing.parse(input)
        let cents = try NumberParsing.cents(p)
        let e = p.whole
        let euroWords = e == 1 ? "un euro" : FrenchNumbers.integer(e) + " euros"
        let centWords = cents == 1 ? "un centime" : FrenchNumbers.integer(cents) + " centimes"
        let display = NumberParsing.euroDisplay(e, cents)
        if e == 0 { return (centWords, centWords, display, e, cents) }
        if cents == 0 { return (euroWords, euroWords, display, e, cents) }
        return ("\(euroWords) \(FrenchNumbers.integer(cents))", "\(euroWords) et \(centWords)", display, e, cents)
    }

    static func phone(_ input: String) throws -> (grouped: String, single: String, display: String) {
        let digits = input.filter(\.isNumber)
        guard digits.count >= 3 else { throw ConversionError("Type at least three digits.") }
        let groups = NumberParsing.groupedDigits(digits, firstGroup: 0, size: 2)
        let words = groups.map { g -> String in
            if g.hasPrefix("0") || g.count == 1 { return g.compactMap(\.wholeNumberValue).map { FrenchNumbers.units[$0] }.joined(separator: " ") }
            return FrenchNumbers.integer(Int(g) ?? 0)
        }
        return (words.joined(separator: ", "), digits.compactMap(\.wholeNumberValue).map { FrenchNumbers.units[$0] }.joined(separator: " "), groups.joined(separator: " "))
    }

    static func weight(grams g: Int) throws -> [String] {
        guard g > 0 && g <= 100_000 else { throw ConversionError("Use a weight from 1 g to 100 kg.") }
        let n = FrenchNumbers.integer
        switch g {
        case 250: return ["deux cent cinquante grammes", "une demi-livre"]
        case 500: return ["une livre", "un demi-kilo", "cinq cents grammes"]
        case 1000: return ["un kilo"]
        case 1500: return ["un kilo et demi"]
        default:
            if g % 1000 == 0 { return ["\(n(g / 1000)) kilos"] }
            if g > 1000 && g % 1000 == 500 { return ["\(n(g / 1000)) kilos et demi"] }
            if g < 1000 { return ["\(n(g)) grammes"] }
            return ["\(g / 1000 == 1 ? "un kilo" : n(g / 1000) + " kilos") \(n(g % 1000))"]
        }
    }
    static func volume(ml: Int) throws -> [String] {
        guard ml > 0 && ml <= 100_000 else { throw ConversionError("Use a volume from 1 ml to 100 l.") }
        let n = FrenchNumbers.integer
        switch ml {
        case 250: return ["un quart de litre"]
        case 500: return ["un demi-litre"]
        case 750: return ["soixante-quinze centilitres", "une bouteille"]
        case 1000: return ["un litre"]
        case 1500: return ["un litre et demi"]
        default:
            if ml % 1000 == 0 { return ["\(n(ml / 1000)) litres"] }
            if ml < 1000 && ml % 10 == 0 { return ["\(n(ml / 10)) centilitres"] }
            if ml < 1000 { return ["\(n(ml)) millilitres"] }
            return ["\(n(ml / 1000)) litres \(n(ml % 1000))"]
        }
    }

    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput {
        let v = input.text.trimmingCharacters(in: .whitespaces)
        switch tool {
        case .numbers, .numerals:
            switch input.mode {
            case "ordinal":
                let n = try NumberParsing.parse(v).whole
                let f = input.form == "f"
                return ToolOutput(label: "Ordinal", headline: try FrenchNumbers.ordinal(n, feminine: f), sub: n == 1 ? (f ? "1re" : "1er") : "\(n)e", rows: [
                    Expr(label: "Étage", text: "le \(try FrenchNumbers.ordinal(n)) étage"),
                    Expr(label: "Siècle", text: "le \(NumberParsing.roman(n))e siècle")])
            case "percent":
                let w = try FrenchNumbers.number(v)
                return ToolOutput(label: "Pourcentage", headline: "\(w) pour cent", sub: v + " %", rows: [Expr(label: "Soldes", text: "moins \(w) pour cent")])
            case "degrees":
                guard Double(v.replacingOccurrences(of: ",", with: ".")) != nil else { throw ConversionError("Type a temperature.") }
                let w = try FrenchNumbers.number(v)
                let words = w == "un" ? "un degré" : w == "moins un" ? "moins un degré" : "\(w) degrés"
                return ToolOutput(label: "Température", headline: words, sub: v + " °C", rows: [Expr(label: "Quel temps fait-il ?", text: "Il fait \(words)")])
            case "floor":
                guard let n = Int(v.split(whereSeparator: { $0 == "," || $0 == "." }).first ?? "") else { throw ConversionError("Type a floor number.") }
                let f = n == 0 ? "le rez-de-chaussée" : n < 0 ? "le sous-sol" : "le \(try FrenchNumbers.ordinal(n)) étage"
                return ToolOutput(label: "Étage", headline: f, sub: n == 0 ? "RDC" : "\(n)", rows: [Expr(label: "J'habite…", text: "J'habite \(n == 0 ? "au rez-de-chaussée" : n < 0 ? "au sous-sol" : "au " + f.replacingOccurrences(of: "le ", with: ""))")])
            default:
                let n = try FrenchNumbers.number(v)
                var rows: [Expr] = []
                if let p = try? NumberParsing.parse(v), p.fraction == nil {
                    if let s = FrenchNumbers.swiss(p.whole) { rows.append(Expr(label: "Belgique, Suisse", text: s)) }
                    if (1...999_999).contains(p.whole), let o = try? FrenchNumbers.ordinal(p.whole) { rows.append(Expr(label: "Ordinal", text: o)) }
                }
                return ToolOutput(label: "En français", headline: n, sub: v, rows: rows)
            }
        case .prices:
            let p = try Self.price(v)
            return ToolOutput(label: "À la caisse", headline: p.spoken, sub: p.display, rows: [Expr(label: "En entier", text: p.formal), Expr(label: "Question", text: "Combien ça coûte ? · Ça fait combien ?")])
        case .time:
            let ex = FrenchTime.expressions(hour: input.hour, minute: input.minute)
            return ToolOutput(label: "Quelle heure est-il ?", headline: ex[0].text, sub: String(format: "%02d:%02d", input.hour, input.minute), rows: Array(ex.dropFirst()))
        case .date, .calendar:
            let w = FrenchTime.date(input.date)
            return ToolOutput(label: "Quel jour sommes-nous ?", headline: w.full, sub: w.numeric, rows: [
                Expr(label: "Court", text: w.short), Expr(label: "Avec l'année", text: w.withYear),
                Expr(label: "Rendez-vous", text: "On se voit \(w.weekday) \(w.short.replacingOccurrences(of: "le ", with: ""))"), Expr(label: "Écrit", text: w.written)])
        case .phone:
            let p = try Self.phone(v)
            return ToolOutput(label: "Par deux", headline: p.grouped, sub: p.display, rows: [Expr(label: "Chiffre par chiffre", text: p.single), Expr(label: "Mon numéro", text: "Mon numéro, c'est le \(p.grouped)")])
        case .market:
            guard let q = Int(v.filter(\.isNumber)) else { throw ConversionError("Type a quantity.") }
            let w = input.unit == "g" ? try Self.weight(grams: q) : try Self.volume(ml: q)
            return ToolOutput(label: "Au marché", headline: "Je voudrais \(w[0]), s'il vous plaît", sub: "\(q) \(input.unit)",
                              rows: w.dropFirst().map { Expr(label: "Ou", text: $0) } + [Expr(label: "Le marchand", text: "Et avec ceci ?"), Expr(label: "Réponse", text: "Ce sera tout, merci")])
        case .years:
            guard let y = Int(v.filter(\.isNumber)), (1...2999).contains(y) else { throw ConversionError("Use a year from 1 to 2999.") }
            let century = (y - 1) / 100 + 1
            var rows = [Expr(label: "En…", text: "en \(FrenchNumbers.integer(y))")]
            if (1100...1999).contains(y) { rows.append(Expr(label: "Aussi", text: "en \(FrenchNumbers.integer(y / 100)) cent \(y % 100 == 0 ? "" : FrenchNumbers.integer(y % 100))".trimmingCharacters(in: .whitespaces))) }
            rows.append(Expr(label: "Siècle", text: "le \(NumberParsing.roman(century))e siècle · le \(try FrenchNumbers.ordinal(century)) siècle"))
            let dec = (y % 100) / 10
            if y >= 1900 && dec >= 2 { rows.append(Expr(label: "Décennie", text: "les années \(FrenchNumbers.integer(dec * 10))")) }
            return ToolOutput(label: "L'année", headline: FrenchNumbers.integer(y), sub: "\(y)", rows: rows)
        case .verbs:
            throw ConversionError("Use conjugate(_:) for verbs.")
        }
    }

    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation? { FrenchConjugator.conjugate(verb, pronouns: pronouns) }

    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using r: inout R) -> DrillItem {
        switch tool {
        case .prices:
            let e = r.int(0...99), c = r.pick([0, 50, 20, 90, 10, 75, 99, 5, 80])
            let p = try! Self.price("\(e),\(String(format: "%02d", c))")
            return DrillItem(spoken: r.chance(0.5) ? p.spoken : p.formal, answer: p.display, placeholder: "12,50", kind: .price(euros: e, cents: c))
        case .time:
            let h = r.int(0...23), m = r.pick([0, 15, 30, 45, 10, 20, 50, 5, 40, 25])
            let ex = FrenchTime.expressions(hour: h, minute: m)
            return DrillItem(spoken: ex[r.int(0...1)].text, answer: String(format: "%d:%02d", h, m), placeholder: "7:45", kind: .time(hour: h, minute: m))
        case .date, .calendar:
            let day = r.int(1...28), month = r.int(1...12)
            let w = FrenchTime.date(Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date())
            return DrillItem(spoken: r.chance(0.5) ? w.full : w.short, answer: "\(day)/\(month)", placeholder: "8/3", kind: .dayMonth(day: day, month: month))
        case .phone:
            let digits = "0\(r.pick([6, 7, 1]))" + String(format: "%08d", r.int(0...99_999_999))
            let p = try! Self.phone(digits)
            return DrillItem(spoken: p.grouped, answer: p.display, placeholder: "06…", kind: .digits(digits))
        case .market:
            let g = r.pick([100, 200, 250, 500, 1000, 1500, 2000])
            return DrillItem(spoken: r.pick(try! Self.weight(grams: g)), answer: "\(g) g", placeholder: "g", kind: .grams(g))
        case .years:
            let y = r.int(1100...2026)
            return DrillItem(spoken: FrenchNumbers.integer(y), answer: "\(y)", placeholder: "1789", kind: .digits("\(y)"))
        default:
            let roll = r.int(0...9)
            let n = roll < 5 ? r.int(60...99) : roll < 7 ? r.int(0...59) : r.int(100...9999)
            return DrillItem(spoken: FrenchNumbers.integer(n), answer: "\(n)", placeholder: "97", kind: .digits("\(n)"))
        }
    }

    private static let cafe: [(String, Double)] = [("Café", 1.80), ("Croissant", 1.20), ("Pain au chocolat", 1.40), ("Baguette", 1.10), ("Croque-monsieur", 6.50), ("Carafe de vin", 9.00), ("Ticket de métro", 2.15), ("Crêpe", 4.50), ("Menu du jour", 16.90), ("Eau minérale", 3.20)]
    private static let routes = [("Paris Gare de Lyon", "Lyon Part-Dieu"), ("Paris Montparnasse", "Bordeaux Saint-Jean"), ("Marseille Saint-Charles", "Nice Ville")]
    private static let works: [(String, String, Int)] = [("Monet", "Impression, soleil levant", 1872), ("Delacroix", "La Liberté guidant le peuple", 1830), ("Seurat", "Un dimanche après-midi à l'île de la Grande Jatte", 1886), ("Renoir", "Bal du moulin de la Galette", 1876), ("Manet", "Le Déjeuner sur l'herbe", 1863), ("Rodin", "Le Penseur", 1904)]

    func realia<R: RandomNumberGenerator>(using r: inout R) -> Realia {
        switch r.int(0...7) {
        case 0, 1:
            let items = Array(Self.cafe.shuffled(using: &r).prefix(r.int(1...3)))
            let total = items.reduce(0) { $0 + $1.1 }
            let p = try! Self.price(String(format: "%.2f", total).replacingOccurrences(of: ".", with: ","))
            var x = Realia(kind: .receipt, question: "Ça fait combien ?", answer: p.spoken, alternative: p.formal, speech: "\(p.formal). \(p.spoken).")
            x.title = "CAFÉ DE LA PLACE"; x.lines = items.map { ($0.0, RealiaFormat.euro($0.1)) }; x.footer = ("TOTAL", RealiaFormat.euro(total))
            return x
        case 2:
            let h = r.int(0...23), m = r.pick([0, 5, 10, 15, 20, 30, 40, 45, 50, 55])
            let ex = FrenchTime.expressions(hour: h, minute: m)
            var x = Realia(kind: .clock, question: "Quelle heure est-il ?", answer: ex[0].text, alternative: ex[1].text, speech: ex[0].text)
            x.hour = h; x.minute = m
            return x
        case 3:
            let d = Calendar.current.date(from: DateComponents(year: 2026, month: r.int(1...12), day: r.int(1...28))) ?? Date()
            let w = FrenchTime.date(d)
            let route = r.pick(Self.routes)
            var x = Realia(kind: .ticket, question: "Le train part quel jour ?", answer: w.full, alternative: w.short, speech: w.full)
            x.title = "\(route.0) → \(route.1)"; x.lines = [("DATE", w.numeric), ("DÉPART", String(format: "%02d:%02d", r.int(6...20), r.pick([4, 16, 34, 52])))]; x.subtitle = "BILLET · 2DE CLASSE"
            return x
        case 4:
            let (name, g) = r.pick([("Comté", 250), ("Cerises", 500), ("Pommes de terre", 2000), ("Jambon", 200), ("Fraises", 500), ("Pâté", 150)])
            let w = try! Self.weight(grams: g)
            var x = Realia(kind: .priceTag, question: "Combien en voulez-vous ?", answer: w[0], alternative: w.dropFirst().joined(separator: " · "), speech: "Je voudrais \(w[0]) de \(name.lowercased()), s'il vous plaît.")
            x.title = name; x.subtitle = "au détail"; x.big = RealiaFormat.quantity(g, "g")
            return x
        case 5:
            let digits = "0\(r.pick([6, 7, 1]))" + String(format: "%08d", r.int(0...99_999_999))
            let p = try! Self.phone(digits)
            var x = Realia(kind: .contact, question: "C'est quoi, le numéro ?", answer: p.grouped, alternative: p.single, speech: p.grouped)
            x.title = r.pick(["Boulangerie Martin", "Hôtel du Parc", "Dr Lefèvre", "Taxi Lumière"]); x.big = p.display; x.subtitle = "Contact"
            return x
        case 6:
            let (a, w, y) = r.pick(Self.works)
            let century = (y - 1) / 100 + 1
            var x = Realia(kind: .museum, question: "C'est de quelle année ?", answer: "en \(FrenchNumbers.integer(y))", alternative: "le \(NumberParsing.roman(century))e siècle", speech: "En \(FrenchNumbers.integer(y)).")
            x.title = a; x.subtitle = w; x.big = "\(y)"
            return x
        default:
            let n = r.int(0...7)
            let f = n == 0 ? "au rez-de-chaussée" : "au \(try! FrenchNumbers.ordinal(n)) étage"
            var x = Realia(kind: .elevator, question: "À quel étage ?", answer: f, alternative: nil, speech: f)
            x.title = "ÉTAGE"; x.big = n == 0 ? "RDC" : "\(n)"
            return x
        }
    }
}

// MARK: - Conjugation

enum FrenchConjugator {
    private static let irregular: [String: (present: [String], participle: String, futureStem: String, imperfectStem: String)] = [
        "être": (["suis", "es", "est", "sommes", "êtes", "sont"], "été", "ser", "ét"),
        "avoir": (["ai", "as", "a", "avons", "avez", "ont"], "eu", "aur", "av"),
        "aller": (["vais", "vas", "va", "allons", "allez", "vont"], "allé", "ir", "all"),
        "faire": (["fais", "fais", "fait", "faisons", "faites", "font"], "fait", "fer", "fais"),
        "dire": (["dis", "dis", "dit", "disons", "dites", "disent"], "dit", "dir", "dis"),
        "pouvoir": (["peux", "peux", "peut", "pouvons", "pouvez", "peuvent"], "pu", "pourr", "pouv"),
        "vouloir": (["veux", "veux", "veut", "voulons", "voulez", "veulent"], "voulu", "voudr", "voul"),
        "devoir": (["dois", "dois", "doit", "devons", "devez", "doivent"], "dû", "devr", "dev"),
        "savoir": (["sais", "sais", "sait", "savons", "savez", "savent"], "su", "saur", "sav"),
        "venir": (["viens", "viens", "vient", "venons", "venez", "viennent"], "venu", "viendr", "ven"),
        "tenir": (["tiens", "tiens", "tient", "tenons", "tenez", "tiennent"], "tenu", "tiendr", "ten"),
        "prendre": (["prends", "prends", "prend", "prenons", "prenez", "prennent"], "pris", "prendr", "pren"),
        "apprendre": (["apprends", "apprends", "apprend", "apprenons", "apprenez", "apprennent"], "appris", "apprendr", "appren"),
        "comprendre": (["comprends", "comprends", "comprend", "comprenons", "comprenez", "comprennent"], "compris", "comprendr", "compren"),
        "mettre": (["mets", "mets", "met", "mettons", "mettez", "mettent"], "mis", "mettr", "mett"),
        "voir": (["vois", "vois", "voit", "voyons", "voyez", "voient"], "vu", "verr", "voy"),
        "croire": (["crois", "crois", "croit", "croyons", "croyez", "croient"], "cru", "croir", "croy"),
        "boire": (["bois", "bois", "boit", "buvons", "buvez", "boivent"], "bu", "boir", "buv"),
        "écrire": (["écris", "écris", "écrit", "écrivons", "écrivez", "écrivent"], "écrit", "écrir", "écriv"),
        "lire": (["lis", "lis", "lit", "lisons", "lisez", "lisent"], "lu", "lir", "lis"),
        "connaître": (["connais", "connais", "connaît", "connaissons", "connaissez", "connaissent"], "connu", "connaîtr", "connaiss"),
        "partir": (["pars", "pars", "part", "partons", "partez", "partent"], "parti", "partir", "part"),
        "sortir": (["sors", "sors", "sort", "sortons", "sortez", "sortent"], "sorti", "sortir", "sort"),
        "dormir": (["dors", "dors", "dort", "dormons", "dormez", "dorment"], "dormi", "dormir", "dorm"),
        "sentir": (["sens", "sens", "sent", "sentons", "sentez", "sentent"], "senti", "sentir", "sent"),
        "servir": (["sers", "sers", "sert", "servons", "servez", "servent"], "servi", "servir", "serv"),
        "ouvrir": (["ouvre", "ouvres", "ouvre", "ouvrons", "ouvrez", "ouvrent"], "ouvert", "ouvrir", "ouvr"),
        "offrir": (["offre", "offres", "offre", "offrons", "offrez", "offrent"], "offert", "offrir", "offr"),
        "recevoir": (["reçois", "reçois", "reçoit", "recevons", "recevez", "reçoivent"], "reçu", "recevr", "recev"),
        "vivre": (["vis", "vis", "vit", "vivons", "vivez", "vivent"], "vécu", "vivr", "viv"),
        "suivre": (["suis", "suis", "suit", "suivons", "suivez", "suivent"], "suivi", "suivr", "suiv"),
        "courir": (["cours", "cours", "court", "courons", "courez", "courent"], "couru", "courr", "cour"),
        "mourir": (["meurs", "meurs", "meurt", "mourons", "mourez", "meurent"], "mort", "mourr", "mour"),
        "naître": (["nais", "nais", "naît", "naissons", "naissez", "naissent"], "né", "naîtr", "naiss"),
        "conduire": (["conduis", "conduis", "conduit", "conduisons", "conduisez", "conduisent"], "conduit", "conduir", "conduis"),
        "plaire": (["plais", "plais", "plaît", "plaisons", "plaisez", "plaisent"], "plu", "plair", "plais"),
        "craindre": (["crains", "crains", "craint", "craignons", "craignez", "craignent"], "craint", "craindr", "craign"),
        "peindre": (["peins", "peins", "peint", "peignons", "peignez", "peignent"], "peint", "peindr", "peign"),
        "envoyer": (["envoie", "envoies", "envoie", "envoyons", "envoyez", "envoient"], "envoyé", "enverr", "envoy"),
        "asseoir": (["assieds", "assieds", "assied", "asseyons", "asseyez", "asseyent"], "assis", "assiér", "assey")
    ]
    /// Verbs taking être in the passé composé (plus every pronominal verb).
    private static let etre: Set<String> = ["aller", "venir", "arriver", "partir", "entrer", "sortir", "monter", "descendre", "naître", "mourir", "rester", "tomber", "retourner", "revenir", "devenir", "passer", "rentrer", "parvenir", "intervenir", "repartir"]

    private static func elide(_ pronoun: String, _ form: String) -> String {
        guard let first = form.first else { return pronoun + " " + form }
        let vowel = "aeéèêiîoôuûhy".contains(first)
        switch pronoun {
        case "je" where vowel: return "j'" + form
        case "me" where vowel, "te" where vowel, "se" where vowel: return String(pronoun.dropLast()) + "'" + form
        default: return pronoun + " " + form
        }
    }

    static func conjugate(_ input: String, pronouns: [String]) -> Conjugation? {
        var lemma = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "’", with: "'")
        var pronominal = false
        if lemma.hasPrefix("se ") { pronominal = true; lemma = String(lemma.dropFirst(3)) }
        else if lemma.hasPrefix("s'") { pronominal = true; lemma = String(lemma.dropFirst(2)) }
        guard lemma.count >= 3, lemma.hasSuffix("er") || lemma.hasSuffix("ir") || lemma.hasSuffix("re") || lemma.hasSuffix("oir") else { return nil }

        var present: [String]
        var participle: String
        var futureStem: String
        var imperfectStem: String
        var note = "régulier"
        var imperfectSoft = false   // mangeais/mangions, commençais/commencions
        if let irr = irregular[lemma] {
            (present, participle, futureStem, imperfectStem) = irr
            note = "irrégulier"
        } else if lemma.hasSuffix("er") {
            let stem = String(lemma.dropLast(2))
            var nousStem = stem
            if stem.hasSuffix("g") { nousStem = stem + "e" }            // mangeons
            if stem.hasSuffix("c") { nousStem = String(stem.dropLast()) + "ç" }  // commençons
            var boot = stem
            if ["appeler", "rappeler", "jeter", "épeler", "renouveler"].contains(lemma) {
                boot = stem + String(stem.last!); note = "consonne doublée"
            } else if ["acheter", "lever", "mener", "amener", "emmener", "promener", "peser", "geler", "élever", "enlever", "soulever"].contains(lemma) {
                boot = replaceLast(stem, "e", "è"); note = "e → è"
            } else if ["préférer", "espérer", "répéter", "considérer", "protéger", "célébrer", "posséder", "suggérer", "compléter", "inquiéter", "régler", "sécher"].contains(lemma) {
                boot = replaceLast(stem, "é", "è"); note = "é → è"
            } else if stem.hasSuffix("y") && !stem.hasSuffix("ay") {
                boot = String(stem.dropLast()) + "i"; note = "y → i"     // nettoyer → nettoie
            }
            present = [boot + "e", boot + "es", boot + "e", nousStem + "ons", stem + "ez", boot + "ent"]
            participle = stem + "é"
            futureStem = (boot != stem && note != "é → è") ? boot + "er" : lemma
            imperfectStem = nousStem
            imperfectSoft = nousStem != stem
        } else if lemma.hasSuffix("ir") {
            let stem = String(lemma.dropLast(2))
            present = [stem + "is", stem + "is", stem + "it", stem + "issons", stem + "issez", stem + "issent"]
            participle = stem + "i"; futureStem = lemma; imperfectStem = stem + "iss"
        } else if lemma.hasSuffix("re") {
            let stem = String(lemma.dropLast(2))
            present = [stem + "s", stem + "s", stem, stem + "ons", stem + "ez", stem + "ent"]
            participle = stem + "u"; futureStem = String(lemma.dropLast()); imperfectStem = stem
        } else { return nil }

        let usesEtre = pronominal || etre.contains(lemma)
        let reflexive = ["me", "te", "se", "nous", "vous", "se"]
        let subjects = ["je", "tu", "il", "nous", "vous", "ils"]
        func full(_ forms: [String]) -> [String] {
            forms.enumerated().map { i, f in pronominal ? subjects[i] + " " + elide(reflexive[i], f) : elide(subjects[i], f) }
        }
        let plainStem = lemma.hasSuffix("er") ? String(lemma.dropLast(2)) : imperfectStem
        let imperfect = ["ais", "ais", "ait", "ions", "iez", "aient"].enumerated().map { i, e in
            (imperfectSoft && (i == 3 || i == 4) ? plainStem : imperfectStem) + e
        }
        let future = ["ai", "as", "a", "ons", "ez", "ont"].map { futureStem + $0 }
        let aux = usesEtre ? ["suis", "es", "est", "sommes", "êtes", "sont"] : ["ai", "as", "a", "avons", "avez", "ont"]
        let pc: [String] = aux.enumerated().map { i, a in
            var p = participle
            if usesEtre { p += i == 2 ? "(e)" : i >= 3 ? "(e)s" : "(e)" }
            if pronominal {
                let refl = ["me", "t'", "s'", "nous", "vous", "se"][i]
                let sep = refl.hasSuffix("'") ? "" : " "
                return "\(subjects[i]) \(refl)\(sep)\(a) \(p)"
            }
            return "\(elide(subjects[i], a)) \(p)"
        }
        let kind = pronominal ? "Verbe pronominal" : note == "irrégulier" ? "Verbe irrégulier" : "Verbe en -\(String(lemma.suffix(2)))"
        // Forms already carry their subject (elision: j'aime), so no separate pronoun column.
        return Conjugation(lemma: input.lowercased(), kind: kind, pronouns: [], tenses: [
            ConjugationTense(name: "Présent", forms: full(present), note: note),
            ConjugationTense(name: "Passé composé", forms: pc, note: "\(usesEtre ? "être" : "avoir") + \(participle)"),
            ConjugationTense(name: "Imparfait", forms: full(imperfect), note: "radical « \(imperfectStem) »"),
            ConjugationTense(name: "Futur simple", forms: full(future), note: "radical « \(futureStem) »")
        ])
    }

    private static func replaceLast(_ s: String, _ from: String, _ to: String) -> String {
        guard let r = s.range(of: from, options: .backwards) else { return s }
        return s.replacingCharacters(in: r, with: to)
    }
}
