import Foundation

/// Spanish (Spain usage: "coma" for decimals, "menos" from :35, "uno de noviembre").
enum SpanishNumbers {
    static let units = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez",
                        "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve",
                        "veinte", "veintiuno", "veintidós", "veintitrés", "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve"]
    static let tens = ["", "", "", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"]
    static let hundreds = ["", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos"]

    private static func below100(_ n: Int) -> String {
        if n < 30 { return units[n] }
        let u = n % 10
        return tens[n / 10] + (u > 0 ? " y " + units[u] : "")
    }
    private static func below1000(_ n: Int) -> String {
        if n < 100 { return below100(n) }
        if n == 100 { return "cien" }
        let r = n % 100
        return hundreds[n / 100] + (r > 0 ? " " + below100(r) : "")
    }
    /// "uno" → "un" before a masculine noun or mil/millón ("veintiún mil", "treinta y un euros").
    static func apocope(_ s: String) -> String {
        if s.hasSuffix("veintiuno") { return String(s.dropLast(9)) + "veintiún" }
        if s.hasSuffix("uno") { return String(s.dropLast(3)) + "un" }
        return s
    }

    static func integer(_ value: Int) -> String {
        if value < 0 { return "menos " + integer(-value) }
        if value < 1000 { return below1000(value) }
        if value < 1_000_000 {
            let th = value / 1000, r = value % 1000
            let head = th == 1 ? "mil" : apocope(below1000(th)) + " mil"
            return head + (r > 0 ? " " + below1000(r) : "")
        }
        if value < 1_000_000_000_000 {
            let mn = value / 1_000_000, r = value % 1_000_000
            let head = mn == 1 ? "un millón" : apocope(integer(mn)) + " millones"
            return head + (r > 0 ? " " + integer(r) : "")
        }
        let bn = value / 1_000_000_000_000, r = value % 1_000_000_000_000
        let head = bn == 1 ? "un billón" : apocope(integer(bn)) + " billones"
        return head + (r > 0 ? " " + integer(r) : "")
    }

    static func number(_ input: String) throws -> String {
        let p = try NumberParsing.parse(input)
        var out = integer(p.whole)
        if let f = p.fraction {
            if f.hasPrefix("0") || f.count > 3 { out += " coma " + f.compactMap(\.wholeNumberValue).map { units[$0] }.joined(separator: " ") }
            else { out += " coma " + integer(Int(f) ?? 0) }
        }
        let nonzero = p.whole != 0 || (p.fraction?.contains { $0 != "0" } ?? false)
        return (p.negative && nonzero ? "menos " : "") + out
    }

    /// Masculine ordinal; `apocopated` gives "primer/tercer" before a masculine noun.
    static func ordinal(_ n: Int, feminine: Bool = false, apocopated: Bool = false) throws -> String {
        guard (1...1000).contains(n) else { throw ConversionError("Use a number from 1 to 1000.") }
        let first = ["", "primero", "segundo", "tercero", "cuarto", "quinto", "sexto", "séptimo", "octavo", "noveno"]
        let tenth = ["", "décimo", "vigésimo", "trigésimo", "cuadragésimo", "quincuagésimo", "sexagésimo", "septuagésimo", "octogésimo", "nonagésimo"]
        let hundredth = ["", "centésimo", "ducentésimo", "tricentésimo", "cuadringentésimo", "quingentésimo", "sexcentésimo", "septingentésimo", "octingentésimo", "noningentésimo"]
        var parts: [String] = []
        if n == 1000 { parts = ["milésimo"] }
        else {
            let h = n / 100, t = (n % 100) / 10, u = n % 10
            if h > 0 { parts.append(hundredth[h]) }
            if t == 1 && u == 1 { parts.append("undécimo") }
            else if t == 1 && u == 2 { parts.append("duodécimo") }
            else if t == 1 && u > 0 { parts.append("decimo" + first[u]) }
            else {
                if t > 0 { parts.append(tenth[t]) }
                if u > 0 { parts.append(first[u]) }
            }
        }
        var s = parts.joined(separator: " ")
        if feminine { s = s.split(separator: " ").map { String($0.dropLast()) + "a" }.joined(separator: " ") }
        else if apocopated && (s.hasSuffix("primero") || s.hasSuffix("tercero")) { s.removeLast() }
        return s
    }
}

enum SpanishTime {
    static let weekdays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    static let months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    private static func hourWord(_ h: Int) -> (article: String, word: String) {
        let h12 = h % 12 == 0 ? 12 : h % 12
        return h12 == 1 ? ("la", "una") : ("las", SpanishNumbers.integer(h12))
    }
    private static func part(_ h: Int) -> String {
        switch h % 24 {
        case 0..<6: return " de la madrugada"
        case 6..<12: return " de la mañana"
        case 12..<20: return " de la tarde"
        default: return " de la noche"
        }
    }
    private static func clause(_ hour: Int, _ minute: Int) -> (hour: Int, tail: String) {
        switch minute {
        case 0: return (hour, " en punto")
        case 15: return (hour, " y cuarto")
        case 30: return (hour, " y media")
        case 45: return (hour + 1, " menos cuarto")
        case 35...59: return (hour + 1, " menos " + SpanishNumbers.integer(60 - minute))
        default: return (hour, " y " + SpanishNumbers.integer(minute))
        }
    }
    static func expressions(hour: Int, minute: Int) -> [Expr] {
        let (h, tail) = clause(hour, minute)
        let hh = ((h % 24) + 24) % 24
        var out: [Expr] = []
        func push(_ l: String, _ t: String) { if !out.contains(where: { $0.text == t }) { out.append(Expr(label: l, text: t)) } }
        if hh == 12 && minute == 0 { push("Habitual", "Es mediodía") }
        else if hh == 0 && minute == 0 { push("Habitual", "Es medianoche") }
        else {
            let w = hourWord(hh)
            push("Habitual", "\(w.article == "la" ? "Es" : "Son") \(w.article) \(w.word)\(tail)")
        }
        let w = hourWord(hh)
        push("Con la parte del día", "\(w.article == "la" ? "Es" : "Son") \(w.article) \(w.word)\(tail == " en punto" ? "" : tail)\(part(hh))")
        if hour >= 13 { push("24 horas", "Son las \(SpanishNumbers.integer(hour))\(minute > 0 ? " " + SpanishNumbers.integer(minute) : "")") }
        push("¿A qué hora?", "Nos vemos a \(w.article) \(w.word)\(tail == " en punto" ? "" : tail)")
        return out
    }
    static func everyday(hour: Int, minute: Int) -> String { expressions(hour: hour, minute: minute)[0].text }

    struct DateWords { var full: String; var short: String; var withYear: String; var numeric: String; var written: String; var weekday: String }
    static func date(_ d: Date, calendar: Calendar = .current) -> DateWords {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: d)
        let day = c.day ?? 1, month = months[(c.month ?? 1) - 1], year = c.year ?? 2000
        let wd = weekdays[(c.weekday ?? 1) - 1]
        let dayWord = SpanishNumbers.integer(day)
        let yearWord = SpanishNumbers.integer(year)
        return DateWords(full: "\(wd), \(dayWord) de \(month) de \(yearWord)", short: "el \(dayWord) de \(month)",
                         withYear: "el \(dayWord) de \(month) de \(yearWord)", numeric: String(format: "%02d/%02d/%d", day, c.month ?? 1, year),
                         written: "\(day) de \(month) de \(year)", weekday: wd)
    }
}

struct SpanishEngine: LanguageEngine {
    let code = LanguageCode.es
    let tools: [ToolKind] = [.numbers, .prices, .time, .date, .phone, .market, .years, .verbs]
    let pronouns = ["yo", "tú", "él / ella", "nosotros", "vosotros", "ellos / ellas"]

    func title(_ tool: ToolKind) -> String {
        switch tool {
        case .numbers, .numerals: return "Números"
        case .prices: return "Precios"
        case .time: return "Hora"
        case .date, .calendar: return "Fecha"
        case .phone: return "Teléfono"
        case .market: return "En el mercado"
        case .years: return "Años y siglos"
        case .verbs: return "Verbos"
        }
    }
    var numberModes: [ChoiceOption] {
        [ChoiceOption(id: "number", label: "Número"), ChoiceOption(id: "ordinal", label: "Ordinal"), ChoiceOption(id: "percent", label: "Porcentaje"),
         ChoiceOption(id: "degrees", label: "Grados"), ChoiceOption(id: "floor", label: "Piso")]
    }
    var ordinalForms: [ChoiceOption] { [ChoiceOption(id: "m", label: "el primero"), ChoiceOption(id: "f", label: "la primera"), ChoiceOption(id: "ap", label: "el primer…")] }

    func clockCard(_ now: Date) -> (question: String, headline: String, line: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return ("¿Qué hora es?", SpanishTime.everyday(hour: c.hour ?? 0, minute: c.minute ?? 0), "Hoy es " + SpanishTime.date(now).full)
    }

    static func price(_ input: String) throws -> (spoken: String, formal: String, display: String, euros: Int, cents: Int) {
        let p = try NumberParsing.parse(input)
        let cents = try NumberParsing.cents(p)
        let e = p.whole
        let euroWords = e == 1 ? "un euro" : SpanishNumbers.apocope(SpanishNumbers.integer(e)) + " euros"
        let centWords = cents == 1 ? "un céntimo" : SpanishNumbers.apocope(SpanishNumbers.integer(cents)) + " céntimos"
        let display = NumberParsing.euroDisplay(e, cents)
        if e == 0 { return (centWords, centWords, display, e, cents) }
        if cents == 0 { return (euroWords, euroWords, display, e, cents) }
        return ("\(SpanishNumbers.integer(e)) con \(SpanishNumbers.integer(cents))", "\(euroWords) con \(centWords)", display, e, cents)
    }

    static func phone(_ input: String) throws -> (grouped: String, single: String, display: String) {
        let digits = input.filter(\.isNumber)
        guard digits.count >= 3 else { throw ConversionError("Type at least three digits.") }
        let groups = NumberParsing.groupedDigits(digits, firstGroup: 0, size: 3)
        let words = groups.map { g -> String in
            if g.hasPrefix("0") || g.count == 1 { return g.compactMap(\.wholeNumberValue).map { SpanishNumbers.units[$0] }.joined(separator: " ") }
            return SpanishNumbers.integer(Int(g) ?? 0)
        }
        return (words.joined(separator: ", "), digits.compactMap(\.wholeNumberValue).map { SpanishNumbers.units[$0] }.joined(separator: " "), groups.joined(separator: " "))
    }

    static func weight(grams g: Int) throws -> [String] {
        guard g > 0 && g <= 100_000 else { throw ConversionError("Use a weight from 1 g to 100 kg.") }
        let n = SpanishNumbers.integer
        switch g {
        case 250: return ["un cuarto de kilo", "doscientos cincuenta gramos"]
        case 500: return ["medio kilo", "quinientos gramos"]
        case 750: return ["tres cuartos de kilo", "setecientos cincuenta gramos"]
        case 1000: return ["un kilo"]
        case 1500: return ["un kilo y medio"]
        default:
            if g % 1000 == 0 { return ["\(n(g / 1000)) kilos"] }
            if g > 1000 && g % 1000 == 500 { return ["\(n(g / 1000)) kilos y medio"] }
            if g < 1000 { return ["\(n(g)) gramos"] }
            return ["\(g / 1000 == 1 ? "un kilo" : n(g / 1000) + " kilos") y \(n(g % 1000)) gramos"]
        }
    }
    static func volume(ml: Int) throws -> [String] {
        guard ml > 0 && ml <= 100_000 else { throw ConversionError("Use a volume from 1 ml to 100 l.") }
        let n = SpanishNumbers.integer
        switch ml {
        case 250: return ["un cuarto de litro"]
        case 330: return ["un tercio", "trescientos treinta mililitros"]
        case 500: return ["medio litro"]
        case 1000: return ["un litro"]
        case 1500: return ["un litro y medio"]
        default:
            if ml % 1000 == 0 { return ["\(n(ml / 1000)) litros"] }
            if ml < 1000 { return ["\(n(ml)) mililitros"] }
            return ["\(n(ml / 1000)) litros y \(n(ml % 1000)) mililitros"]
        }
    }

    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput {
        let v = input.text.trimmingCharacters(in: .whitespaces)
        switch tool {
        case .numbers, .numerals:
            switch input.mode {
            case "ordinal":
                let n = try NumberParsing.parse(v).whole
                let text = try SpanishNumbers.ordinal(n, feminine: input.form == "f", apocopated: input.form == "ap")
                return ToolOutput(label: "Ordinal", headline: text, sub: "\(n)\(input.form == "f" ? "ª" : "º")", rows: [
                    Expr(label: "Piso", text: "el \(try SpanishNumbers.ordinal(n, apocopated: true)) piso"),
                    Expr(label: "Vez", text: "la \(try SpanishNumbers.ordinal(n, feminine: true)) vez"),
                    Expr(label: "Siglo", text: "el siglo \(NumberParsing.roman(n))")])
            case "percent":
                let w = try SpanishNumbers.number(v)
                return ToolOutput(label: "Porcentaje", headline: "\(w) por ciento", sub: v + " %", rows: [Expr(label: "Rebajas", text: "un descuento del \(w) por ciento")])
            case "degrees":
                guard let t = Double(v.replacingOccurrences(of: ",", with: ".")) else { throw ConversionError("Type a temperature.") }
                let w = try SpanishNumbers.number(v)
                let words = abs(t) == 1 ? (t < 0 ? "menos un grado" : "un grado") : "\(w) grados"
                return ToolOutput(label: "Temperatura", headline: words, sub: v + " °C", rows: [Expr(label: "¿Qué tiempo hace?", text: "Hace \(words)"), Expr(label: "Bajo cero", text: t < 0 ? "\(SpanishNumbers.integer(Int(abs(t)))) grados bajo cero" : "—")].filter { $0.text != "—" })
            case "floor":
                guard let n = Int(v.split(whereSeparator: { $0 == "," || $0 == "." }).first ?? "") else { throw ConversionError("Type a floor number.") }
                let f = n == 0 ? "la planta baja" : n < 0 ? "el sótano" : "el \(try SpanishNumbers.ordinal(n, apocopated: true)) piso"
                return ToolOutput(label: "Piso", headline: f, sub: n == 0 ? "PB" : "\(n)", rows: [Expr(label: "Vivo en…", text: "Vivo en \(f)")])
            default:
                let n = try SpanishNumbers.number(v)
                var rows: [Expr] = []
                if let p = try? NumberParsing.parse(v), p.fraction == nil, (1...1000).contains(p.whole), let o = try? SpanishNumbers.ordinal(p.whole) { rows.append(Expr(label: "Ordinal", text: o)) }
                return ToolOutput(label: "En español", headline: n, sub: v, rows: rows)
            }
        case .prices:
            let p = try Self.price(v)
            return ToolOutput(label: "En la caja", headline: p.spoken, sub: p.display, rows: [Expr(label: "Completo", text: p.formal), Expr(label: "Pregunta", text: "¿Cuánto cuesta? · ¿Cuánto es?")])
        case .time:
            let ex = SpanishTime.expressions(hour: input.hour, minute: input.minute)
            return ToolOutput(label: "¿Qué hora es?", headline: ex[0].text, sub: String(format: "%02d:%02d", input.hour, input.minute), rows: Array(ex.dropFirst()))
        case .date, .calendar:
            let w = SpanishTime.date(input.date)
            return ToolOutput(label: "¿Qué día es?", headline: w.full, sub: w.numeric, rows: [
                Expr(label: "Corto", text: w.short), Expr(label: "Con el año", text: w.withYear),
                Expr(label: "Cita", text: "Nos vemos el \(w.weekday) \(w.short.replacingOccurrences(of: "el ", with: ""))"), Expr(label: "Escrito", text: w.written)])
        case .phone:
            let p = try Self.phone(v)
            return ToolOutput(label: "En grupos", headline: p.grouped, sub: p.display, rows: [Expr(label: "Cifra a cifra", text: p.single), Expr(label: "Mi número", text: "Mi número es el \(p.grouped)")])
        case .market:
            guard let q = Int(v.filter(\.isNumber)) else { throw ConversionError("Type a quantity.") }
            let w = input.unit == "g" ? try Self.weight(grams: q) : try Self.volume(ml: q)
            return ToolOutput(label: "En el mercado", headline: "Póngame \(w[0]), por favor", sub: "\(q) \(input.unit)",
                              rows: w.dropFirst().map { Expr(label: "O bien", text: $0) } + [Expr(label: "El vendedor", text: "¿Algo más?"), Expr(label: "Respuesta", text: "Nada más, gracias")])
        case .years:
            guard let y = Int(v.filter(\.isNumber)), (1...2999).contains(y) else { throw ConversionError("Use a year from 1 to 2999.") }
            let century = (y - 1) / 100 + 1
            var rows = [Expr(label: "En…", text: "en \(SpanishNumbers.integer(y))"),
                        Expr(label: "Siglo", text: "el siglo \(NumberParsing.roman(century)) · el siglo \(SpanishNumbers.integer(century))")]
            let dec = (y % 100) / 10
            if y >= 1900 && dec >= 2 { rows.append(Expr(label: "Década", text: "los años \(SpanishNumbers.integer(dec * 10))")) }
            return ToolOutput(label: "El año", headline: SpanishNumbers.integer(y), sub: "\(y)", rows: rows)
        case .verbs:
            throw ConversionError("Use conjugate(_:) for verbs.")
        }
    }

    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation? { SpanishConjugator.conjugate(verb, pronouns: pronouns) }

    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using r: inout R) -> DrillItem {
        switch tool {
        case .prices:
            let e = r.int(0...99), c = r.pick([0, 50, 20, 90, 10, 75, 99, 5])
            let p = try! Self.price("\(e),\(String(format: "%02d", c))")
            return DrillItem(spoken: r.chance(0.5) ? p.spoken : p.formal, answer: p.display, placeholder: "12,50", kind: .price(euros: e, cents: c))
        case .time:
            let h = r.int(0...23), m = r.pick([0, 15, 30, 45, 10, 20, 50, 5, 40, 25])
            let ex = SpanishTime.expressions(hour: h, minute: m)
            return DrillItem(spoken: ex[r.int(0...min(1, ex.count - 1))].text, answer: String(format: "%d:%02d", h, m), placeholder: "7:45", kind: .time(hour: h, minute: m))
        case .date, .calendar:
            let day = r.int(1...28), month = r.int(1...12)
            let w = SpanishTime.date(Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date())
            return DrillItem(spoken: r.chance(0.5) ? w.full : w.short, answer: "\(day)/\(month)", placeholder: "8/3", kind: .dayMonth(day: day, month: month))
        case .phone:
            let digits = "6\(r.int(0...9))\(r.int(0...9))" + String(format: "%06d", r.int(0...999_999))
            let p = try! Self.phone(digits)
            return DrillItem(spoken: r.chance(0.6) ? p.grouped : p.single, answer: p.display, placeholder: "612…", kind: .digits(digits))
        case .market:
            let g = r.pick([100, 200, 250, 300, 500, 750, 1000, 1500, 2000])
            return DrillItem(spoken: r.pick(try! Self.weight(grams: g)), answer: "\(g) g", placeholder: "g", kind: .grams(g))
        case .years:
            let y = r.int(1100...2026)
            return DrillItem(spoken: SpanishNumbers.integer(y), answer: "\(y)", placeholder: "1492", kind: .digits("\(y)"))
        default:
            let roll = r.int(0...9)
            let n = roll < 4 ? r.int(0...99) : roll < 7 ? r.int(100...999) : r.int(1000...99_999)
            return DrillItem(spoken: SpanishNumbers.integer(n), answer: "\(n)", placeholder: "123", kind: .digits("\(n)"))
        }
    }

    private static let bar: [(String, Double)] = [("Café con leche", 1.60), ("Caña", 2.20), ("Tostada", 2.50), ("Tortilla", 3.80), ("Churros", 3.00), ("Agua", 1.20), ("Menú del día", 12.50), ("Bocadillo", 4.50), ("Vino tinto", 2.80), ("Billete de metro", 1.50)]
    private static let routes = [("Madrid Atocha", "Sevilla Santa Justa"), ("Barcelona Sants", "Valencia Joaquín Sorolla"), ("Madrid Chamartín", "Bilbao Abando")]
    private static let works: [(String, String, Int)] = [("Velázquez", "Las meninas", 1656), ("Goya", "El tres de mayo", 1814), ("Picasso", "Guernica", 1937), ("El Greco", "El caballero de la mano en el pecho", 1580), ("Murillo", "La Inmaculada", 1678), ("Dalí", "La persistencia de la memoria", 1931)]

    func realia<R: RandomNumberGenerator>(using r: inout R) -> Realia {
        switch r.int(0...7) {
        case 0, 1:
            let items = Array(Self.bar.shuffled(using: &r).prefix(r.int(1...3)))
            let total = items.reduce(0) { $0 + $1.1 }
            let p = try! Self.price(String(format: "%.2f", total).replacingOccurrences(of: ".", with: ","))
            var x = Realia(kind: .receipt, question: "¿Cuánto es?", answer: p.spoken, alternative: p.formal, speech: "\(p.formal). \(p.spoken).")
            x.title = "CAFETERÍA LA PLAZA"; x.lines = items.map { ($0.0, RealiaFormat.euro($0.1)) }; x.footer = ("TOTAL", RealiaFormat.euro(total))
            return x
        case 2:
            let h = r.int(0...23), m = r.pick([0, 5, 10, 15, 20, 30, 40, 45, 50, 55])
            let ex = SpanishTime.expressions(hour: h, minute: m)
            var x = Realia(kind: .clock, question: "¿Qué hora es?", answer: ex[0].text, alternative: ex.dropFirst().prefix(2).map(\.text).joined(separator: " · "), speech: ex[0].text)
            x.hour = h; x.minute = m
            return x
        case 3:
            let d = Calendar.current.date(from: DateComponents(year: 2026, month: r.int(1...12), day: r.int(1...28))) ?? Date()
            let w = SpanishTime.date(d)
            let route = r.pick(Self.routes)
            var x = Realia(kind: .ticket, question: "¿Qué día sale el tren?", answer: w.full, alternative: w.short, speech: w.full)
            x.title = "\(route.0) → \(route.1)"; x.lines = [("FECHA", w.numeric), ("SALIDA", String(format: "%02d:%02d", r.int(6...20), r.pick([5, 15, 30, 45])))]; x.subtitle = "BILLETE · TURISTA"
            return x
        case 4:
            let (name, g) = r.pick([("Jamón serrano", 250), ("Queso manchego", 500), ("Tomates", 1000), ("Aceitunas", 250), ("Naranjas", 2000), ("Chorizo", 300)])
            let w = try! Self.weight(grams: g)
            var x = Realia(kind: .priceTag, question: "¿Cuánto le pongo?", answer: "\(w[0]) de \(name.lowercased())", alternative: w.dropFirst().joined(separator: " · "), speech: "Póngame \(w[0]) de \(name.lowercased()), por favor.")
            x.title = name; x.subtitle = "al corte"; x.big = RealiaFormat.quantity(g, "g")
            return x
        case 5:
            let digits = "6\(r.int(0...9))\(r.int(0...9))" + String(format: "%06d", r.int(0...999_999))
            let p = try! Self.phone(digits)
            var x = Realia(kind: .contact, question: "¿Cuál es el número?", answer: p.grouped, alternative: p.single, speech: p.grouped)
            x.title = r.pick(["Farmacia Sol", "Hostal Miramar", "Taxi Madrid", "Dra. García"]); x.big = p.display; x.subtitle = "Contacto"
            return x
        case 6:
            let (a, w, y) = r.pick(Self.works)
            let century = (y - 1) / 100 + 1
            var x = Realia(kind: .museum, question: "¿De qué año es?", answer: "en \(SpanishNumbers.integer(y))", alternative: "el siglo \(NumberParsing.roman(century))", speech: "En \(SpanishNumbers.integer(y)). Siglo \(SpanishNumbers.integer(century)).")
            x.title = a; x.subtitle = w; x.big = "\(y)"
            return x
        default:
            let t = r.int(-6...42)
            let words = abs(t) == 1 ? (t < 0 ? "menos un grado" : "un grado") : "\(SpanishNumbers.integer(t)) grados"
            var x = Realia(kind: .pharmacy, question: "¿Cuántos grados hace?", answer: words, alternative: "Hace \(words)", speech: "Hace \(words)")
            x.title = "+ FARMACIA +"; x.big = "\(t)°"
            return x
        }
    }
}

// MARK: - Conjugation

enum SpanishConjugator {
    private static let irregularPresent: [String: [String]] = [
        "ser": ["soy", "eres", "es", "somos", "sois", "son"], "estar": ["estoy", "estás", "está", "estamos", "estáis", "están"],
        "ir": ["voy", "vas", "va", "vamos", "vais", "van"], "haber": ["he", "has", "ha", "hemos", "habéis", "han"],
        "tener": ["tengo", "tienes", "tiene", "tenemos", "tenéis", "tienen"], "hacer": ["hago", "haces", "hace", "hacemos", "hacéis", "hacen"],
        "decir": ["digo", "dices", "dice", "decimos", "decís", "dicen"], "venir": ["vengo", "vienes", "viene", "venimos", "venís", "vienen"],
        "poner": ["pongo", "pones", "pone", "ponemos", "ponéis", "ponen"], "salir": ["salgo", "sales", "sale", "salimos", "salís", "salen"],
        "traer": ["traigo", "traes", "trae", "traemos", "traéis", "traen"], "oír": ["oigo", "oyes", "oye", "oímos", "oís", "oyen"],
        "dar": ["doy", "das", "da", "damos", "dais", "dan"], "ver": ["veo", "ves", "ve", "vemos", "veis", "ven"],
        "saber": ["sé", "sabes", "sabe", "sabemos", "sabéis", "saben"], "caber": ["quepo", "cabes", "cabe", "cabemos", "cabéis", "caben"],
        "caer": ["caigo", "caes", "cae", "caemos", "caéis", "caen"], "valer": ["valgo", "vales", "vale", "valemos", "valéis", "valen"],
        "oler": ["huelo", "hueles", "huele", "olemos", "oléis", "huelen"], "jugar": ["juego", "juegas", "juega", "jugamos", "jugáis", "juegan"]
    ]
    private static let preterite: [String: [String]] = [
        "ser": ["fui", "fuiste", "fue", "fuimos", "fuisteis", "fueron"], "ir": ["fui", "fuiste", "fue", "fuimos", "fuisteis", "fueron"],
        "estar": ["estuve", "estuviste", "estuvo", "estuvimos", "estuvisteis", "estuvieron"], "tener": ["tuve", "tuviste", "tuvo", "tuvimos", "tuvisteis", "tuvieron"],
        "hacer": ["hice", "hiciste", "hizo", "hicimos", "hicisteis", "hicieron"], "poder": ["pude", "pudiste", "pudo", "pudimos", "pudisteis", "pudieron"],
        "poner": ["puse", "pusiste", "puso", "pusimos", "pusisteis", "pusieron"], "saber": ["supe", "supiste", "supo", "supimos", "supisteis", "supieron"],
        "querer": ["quise", "quisiste", "quiso", "quisimos", "quisisteis", "quisieron"], "venir": ["vine", "viniste", "vino", "vinimos", "vinisteis", "vinieron"],
        "decir": ["dije", "dijiste", "dijo", "dijimos", "dijisteis", "dijeron"], "traer": ["traje", "trajiste", "trajo", "trajimos", "trajisteis", "trajeron"],
        "dar": ["di", "diste", "dio", "dimos", "disteis", "dieron"], "ver": ["vi", "viste", "vio", "vimos", "visteis", "vieron"],
        "haber": ["hube", "hubiste", "hubo", "hubimos", "hubisteis", "hubieron"], "andar": ["anduve", "anduviste", "anduvo", "anduvimos", "anduvisteis", "anduvieron"],
        "conducir": ["conduje", "condujiste", "condujo", "condujimos", "condujisteis", "condujeron"], "caber": ["cupe", "cupiste", "cupo", "cupimos", "cupisteis", "cupieron"],
        "leer": ["leí", "leíste", "leyó", "leímos", "leísteis", "leyeron"], "oír": ["oí", "oíste", "oyó", "oímos", "oísteis", "oyeron"],
        "caer": ["caí", "caíste", "cayó", "caímos", "caísteis", "cayeron"], "creer": ["creí", "creíste", "creyó", "creímos", "creísteis", "creyeron"]
    ]
    private static let imperfect: [String: [String]] = [
        "ser": ["era", "eras", "era", "éramos", "erais", "eran"], "ir": ["iba", "ibas", "iba", "íbamos", "ibais", "iban"],
        "ver": ["veía", "veías", "veía", "veíamos", "veíais", "veían"]
    ]
    private static let futureStems: [String: String] = [
        "tener": "tendr", "poner": "pondr", "salir": "saldr", "venir": "vendr", "valer": "valdr", "poder": "podr", "saber": "sabr",
        "caber": "cabr", "haber": "habr", "querer": "querr", "decir": "dir", "hacer": "har"
    ]
    private static let participles: [String: String] = [
        "abrir": "abierto", "decir": "dicho", "escribir": "escrito", "hacer": "hecho", "morir": "muerto", "poner": "puesto",
        "romper": "roto", "ver": "visto", "volver": "vuelto", "cubrir": "cubierto", "resolver": "resuelto", "devolver": "devuelto",
        "descubrir": "descubierto", "freír": "frito", "imprimir": "impreso", "satisfacer": "satisfecho", "deshacer": "deshecho"
    ]
    /// Stem-changing verbs in the present (boot pattern).
    private static let eToIe: Set<String> = ["pensar", "querer", "empezar", "cerrar", "comenzar", "entender", "perder", "preferir", "sentir", "mentir", "despertar", "sentar", "encender", "defender", "tener", "venir", "nevar", "convertir", "divertir", "advertir", "sugerir", "referir", "atravesar", "calentar", "confesar", "recomendar", "negar", "regar", "fregar", "gobernar", "merendar"]
    private static let oToUe: Set<String> = ["poder", "volver", "dormir", "contar", "encontrar", "costar", "recordar", "mostrar", "morir", "mover", "soler", "llover", "probar", "almorzar", "volar", "sonar", "soñar", "devolver", "resolver", "doler", "torcer", "aprobar", "acostar", "colgar", "rogar", "resolver"]
    private static let eToI: Set<String> = ["pedir", "servir", "repetir", "seguir", "vestir", "conseguir", "elegir", "medir", "reír", "sonreír", "corregir", "despedir", "impedir", "competir", "perseguir", "freír"]

    static func conjugate(_ input: String, pronouns: [String]) -> Conjugation? {
        var lemma = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lemma.count >= 2 else { return nil }
        var reflexive = false
        if lemma.hasSuffix("se") && (lemma.hasSuffix("arse") || lemma.hasSuffix("erse") || lemma.hasSuffix("irse") || lemma.hasSuffix("írse")) {
            reflexive = true; lemma = String(lemma.dropLast(2))
        }
        let ending = String(lemma.suffix(2))
        guard ["ar", "er", "ir", "ír"].contains(ending) else { return nil }
        let stem = String(lemma.dropLast(2))
        let isAr = ending == "ar", isEr = ending == "er"

        func changed(_ s: String, from: String, to: String) -> String {
            guard let r = s.range(of: from, options: .backwards) else { return s }
            return s.replacingCharacters(in: r, with: to)
        }
        // Present
        var present: [String]
        var irregular = false
        if let f = irregularPresent[lemma] { present = f; irregular = true }
        else {
            let endings = isAr ? ["o", "as", "a", "amos", "áis", "an"] : isEr ? ["o", "es", "e", "emos", "éis", "en"] : ["o", "es", "e", "imos", "ís", "en"]
            var boot = stem
            if eToIe.contains(lemma) { boot = changed(stem, from: "e", to: "ie") }
            else if oToUe.contains(lemma) { boot = changed(stem, from: "o", to: "ue") }
            else if eToI.contains(lemma) { boot = changed(stem, from: "e", to: "i") }
            present = endings.enumerated().map { i, e in (i == 3 || i == 4 ? stem : boot) + e }
            if lemma.hasSuffix("cer") || lemma.hasSuffix("cir"), !["hacer", "decir", "torcer", "cocer", "mecer", "vencer", "convencer", "ejercer"].contains(lemma) {
                present[0] = String(stem.dropLast()) + "zco"   // conocer → conozco, traducir → traduzco
            }
            if lemma.hasSuffix("uir") && !lemma.hasSuffix("guir") {   // construir → construyo
                present = present.enumerated().map { i, f in (i == 3 || i == 4) ? f : stem + "y" + String(f.dropFirst(stem.count)) }
            }
            if lemma.hasSuffix("ger") || lemma.hasSuffix("gir") { present[0] = changed(present[0], from: "go", to: "jo") }
            if lemma.hasSuffix("guir") { present[0] = changed(present[0], from: "guo", to: "go") }
            if ["tener", "venir", "poner", "salir", "valer"].contains(lemma) { irregular = true }
        }
        // Preterite
        var pret: [String]
        if let f = preterite[lemma] { pret = f }
        else {
            pret = isAr ? ["é", "aste", "ó", "amos", "asteis", "aron"].map { stem + $0 } : ["í", "iste", "ió", "imos", "isteis", "ieron"].map { stem + $0 }
            if isAr {
                if stem.hasSuffix("c") { pret[0] = String(stem.dropLast()) + "qué" }
                else if stem.hasSuffix("g") { pret[0] = stem + "ué" }
                else if stem.hasSuffix("z") { pret[0] = String(stem.dropLast()) + "cé" }
            } else if !isEr && (eToI.contains(lemma) || ["sentir", "preferir", "mentir", "convertir", "divertir", "sugerir", "advertir", "referir"].contains(lemma)) {
                let s3 = changed(stem, from: "e", to: "i")
                pret[2] = s3 + "ió"; pret[5] = s3 + "ieron"
            } else if ["dormir", "morir"].contains(lemma) {
                let s3 = changed(stem, from: "o", to: "u")
                pret[2] = s3 + "ió"; pret[5] = s3 + "ieron"
            }
            if lemma.hasSuffix("cir") && !["decir"].contains(lemma) && preterite[lemma] == nil {   // traducir → traduje
                let s = String(stem.dropLast()) + "j"
                pret = ["e", "iste", "o", "imos", "isteis", "eron"].map { s + $0 }
            }
        }
        // Imperfect
        let imp = imperfect[lemma] ?? (isAr ? ["aba", "abas", "aba", "ábamos", "abais", "aban"].map { stem + $0 } : ["ía", "ías", "ía", "íamos", "íais", "ían"].map { stem + $0 })
        // Future
        let fstem = futureStems[lemma] ?? lemma.replacingOccurrences(of: "ír", with: "ir")
        let fut = ["é", "ás", "á", "emos", "éis", "án"].map { fstem + $0 }
        // Perfect
        let part = participles[lemma] ?? (isAr ? stem + "ado" : (stem.hasSuffix("a") || stem.hasSuffix("e") || stem.hasSuffix("o") ? stem + "ído" : stem + "ido"))
        let perfect = ["he", "has", "ha", "hemos", "habéis", "han"].map { "\($0) \(part)" }

        let refl = ["me", "te", "se", "nos", "os", "se"]
        func wrap(_ f: [String]) -> [String] { reflexive ? zip(refl, f).map { "\($0) \($1)" } : f }
        let kind = reflexive ? "Verbo reflexivo" : irregular ? "Verbo irregular" : "Verbo regular en -\(ending)"
        return Conjugation(lemma: input.lowercased(), kind: kind, pronouns: pronouns, tenses: [
            ConjugationTense(name: "Presente", forms: wrap(present), note: irregular ? "irregular" : (eToIe.contains(lemma) || oToUe.contains(lemma) || eToI.contains(lemma)) ? "cambio de raíz" : "regular"),
            ConjugationTense(name: "Pretérito perfecto", forms: wrap(perfect), note: "haber + \(part)"),
            ConjugationTense(name: "Pretérito indefinido", forms: wrap(pret), note: preterite[lemma] != nil ? "irregular" : "regular"),
            ConjugationTense(name: "Imperfecto", forms: wrap(imp), note: imperfect[lemma] != nil ? "irregular" : "regular"),
            ConjugationTense(name: "Futuro", forms: wrap(fut), note: futureStems[lemma] != nil ? "raíz irregular" : "regular")
        ])
    }
}
