import Foundation

/// European Portuguese: long scale, European teens and decimal vírgula.
enum PortugueseNumbers {
    static let units = ["zero", "um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez", "onze", "doze", "treze", "catorze", "quinze", "dezasseis", "dezassete", "dezoito", "dezanove"]
    private static let tens = ["", "", "vinte", "trinta", "quarenta", "cinquenta", "sessenta", "setenta", "oitenta", "noventa"]
    private static let hundreds = ["", "cento", "duzentos", "trezentos", "quatrocentos", "quinhentos", "seiscentos", "setecentos", "oitocentos", "novecentos"]

    static func integer(_ value: Int, feminine: Bool = false) -> String {
        if value < 0 { return "menos " + integer(-value, feminine: feminine) }
        if value < 20 {
            if feminine && value == 1 { return "uma" }
            if feminine && value == 2 { return "duas" }
            return units[value]
        }
        if value < 100 { return tens[value / 10] + (value % 10 == 0 ? "" : " e " + integer(value % 10, feminine: feminine)) }
        if value == 100 { return "cem" }
        if value < 1000 {
            let h = hundreds[value / 100]
            return (feminine && value >= 200 ? String(h.dropLast(2)) + "as" : h)
                + (value % 100 == 0 ? "" : " e " + integer(value % 100, feminine: feminine))
        }
        let scale: Int, singular: String, plural: String
        if value < 1_000_000 { scale = 1000; singular = "mil"; plural = "mil" }
        else if value < 1_000_000_000_000 { scale = 1_000_000; singular = "milhão"; plural = "milhões" }
        else { scale = 1_000_000_000_000; singular = "bilião"; plural = "biliões" }
        let count = value / scale, rest = value % scale
        let head = scale == 1000 && count == 1 ? "mil" : integer(count, feminine: scale == 1000 && feminine) + " " + (count == 1 ? singular : plural)
        let join = rest < 100 || (rest < 1000 && rest % 100 == 0) ? " e " : " "
        return head + (rest == 0 ? "" : join + integer(rest, feminine: feminine))
    }

    static func number(_ input: String) throws -> String {
        let p = try NumberParsing.parse(input)
        var text = integer(p.whole)
        if let fraction = p.fraction {
            let spoken = fraction.hasPrefix("0") || fraction.count > 3
                ? fraction.compactMap(\.wholeNumberValue).map { units[$0] }.joined(separator: " ")
                : integer(Int(fraction) ?? 0)
            text += " vírgula " + spoken
        }
        return (p.negative && (p.whole != 0 || p.fraction?.contains(where: { $0 != "0" }) == true) ? "menos " : "") + text
    }

    static func ordinal(_ n: Int, feminine: Bool = false) throws -> String {
        guard (1...1000).contains(n) else { throw ConversionError("Use a number from 1 to 1000.") }
        let units = ["", "primeiro", "segundo", "terceiro", "quarto", "quinto", "sexto", "sétimo", "oitavo", "nono"]
        let tens = ["", "décimo", "vigésimo", "trigésimo", "quadragésimo", "quinquagésimo", "sexagésimo", "septuagésimo", "octogésimo", "nonagésimo"]
        let hundreds = ["", "centésimo", "ducentésimo", "tricentésimo", "quadringentésimo", "quingentésimo", "sexcentésimo", "septingentésimo", "octingentésimo", "nongentésimo"]
        let parts = n == 1000 ? ["milésimo"] : [hundreds[n / 100], tens[n % 100 / 10], units[n % 10]].filter { !$0.isEmpty }
        return parts.map { feminine ? String($0.dropLast()) + "a" : $0 }.joined(separator: " ")
    }
}

enum PortugueseTime {
    static let weekdays = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    static let months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    private static func hour(_ h: Int) -> String {
        let h = (h % 24 + 24) % 24
        if h == 0 { return "meia-noite" }
        if h == 12 { return "meio-dia" }
        return PortugueseNumbers.integer(h % 12, feminine: true)
    }
    static func expressions(hour h: Int, minute m: Int) -> [Expr] {
        let h = (h % 24 + 24) % 24
        let next = m > 30 ? (h + 1) % 24 : h
        let tail: String
        switch m {
        case 0: tail = " em ponto"
        case 15: tail = " e um quarto"
        case 30: tail = " e meia"
        case 45: tail = " menos um quarto"
        case 31...59: tail = " menos " + PortugueseNumbers.integer(60 - m) + (m == 59 ? " minuto" : "")
        default: tail = " e " + PortugueseNumbers.integer(m) + (m == 1 ? " minuto" : "")
        }
        let singular = next == 0 || next == 12 || next % 12 == 1
        let at = next == 12 ? "ao" : singular ? "à" : "às"
        let phrase = "\(singular ? "É" : "São") \(hour(next))\(tail)"
        let clock = "\(PortugueseNumbers.integer(h, feminine: true)) \(h == 1 ? "hora" : "horas")" + (m == 0 ? "" : " e \(PortugueseNumbers.integer(m)) \(m == 1 ? "minuto" : "minutos")")
        return [Expr(label: "Habitual", text: phrase), Expr(label: "24 horas", text: (h == 1 ? "É " : "São ") + clock),
                Expr(label: "A que horas?", text: "Encontramo-nos \(at) \(hour(next))\(m == 0 ? "" : tail)")]
    }
    static func everyday(hour: Int, minute: Int) -> String { expressions(hour: hour, minute: minute)[0].text }
    struct DateWords { var full: String; var short: String; var numeric: String; var written: String; var weekday: String }
    static func date(_ date: Date, calendar: Calendar = .current) -> DateWords {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: date)
        let d = c.day ?? 1, m = c.month ?? 1, y = c.year ?? 2000
        let weekday = weekdays[(c.weekday ?? 1) - 1]
        let day = d == 1 ? "primeiro" : PortugueseNumbers.integer(d)
        let short = "\(day) de \(months[m - 1])"
        return DateWords(full: "\(weekday), \(short) de \(PortugueseNumbers.integer(y))", short: short,
                         numeric: String(format: "%02d/%02d/%d", d, m, y), written: "\(d) de \(months[m - 1]) de \(y)", weekday: weekday)
    }
}

struct PortugueseEngine: LanguageEngine {
    let code = LanguageCode.pt
    let tools: [ToolKind] = [.numbers, .prices, .time, .date, .phone, .market, .years, .verbs]
    let pronouns = ["eu", "tu", "ele / ela", "nós", "vós", "eles / elas"]
    func title(_ tool: ToolKind) -> String {
        switch tool {
        case .numbers, .numerals: return "Números"
        case .prices: return "Preços"
        case .time: return "Horas"
        case .date, .calendar: return "Data"
        case .phone: return "Telefone"
        case .market: return "No mercado"
        case .years: return "Anos e séculos"
        case .verbs: return "Verbos"
        }
    }
    var numberModes: [ChoiceOption] { [ChoiceOption(id: "number", label: "Número"), ChoiceOption(id: "ordinal", label: "Ordinal"), ChoiceOption(id: "percent", label: "Percentagem"), ChoiceOption(id: "degrees", label: "Graus"), ChoiceOption(id: "floor", label: "Andar")] }
    var ordinalForms: [ChoiceOption] { [ChoiceOption(id: "m", label: "o primeiro"), ChoiceOption(id: "f", label: "a primeira")] }
    func clockCard(_ now: Date) -> (question: String, headline: String, line: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return ("Que horas são?", PortugueseTime.everyday(hour: c.hour ?? 0, minute: c.minute ?? 0), "Hoje é " + PortugueseTime.date(now).full)
    }
    static func price(_ input: String) throws -> (spoken: String, formal: String, display: String, euros: Int, cents: Int) {
        let p = try NumberParsing.parse(input), c = try NumberParsing.cents(p)
        guard !p.negative else { throw ConversionError("Use a positive price.") }
        let e = p.whole
        let euros = "\(PortugueseNumbers.integer(e)) \(e > 0 && e % 1_000_000 == 0 ? "de " : "")\(e == 1 ? "euro" : "euros")"
        let cents = "\(PortugueseNumbers.integer(c)) \(c == 1 ? "cêntimo" : "cêntimos")"
        let formal = e == 0 && c > 0 ? cents : euros + (c > 0 ? " e " + cents : "")
        let spoken = e == 0 || c == 0 ? formal : euros + " e " + PortugueseNumbers.integer(c)
        return (spoken, formal, String(format: "%d,%02d €", e, c), e, c)
    }
    static func phone(_ input: String) throws -> (grouped: String, single: String, display: String) {
        let digits = input.filter { $0.isASCII && $0.isNumber }
        guard (3...15).contains(digits.count) else { throw ConversionError("Use 3 to 15 phone digits.") }
        let groups = NumberParsing.groupedDigits(digits, firstGroup: 0, size: 3)
        let words = groups.map { group in group.hasPrefix("0") ? group.compactMap(\.wholeNumberValue).map { PortugueseNumbers.units[$0] }.joined(separator: " ") : PortugueseNumbers.integer(Int(group) ?? 0) }
        return (words.joined(separator: ", "), digits.compactMap(\.wholeNumberValue).map { PortugueseNumbers.units[$0] }.joined(separator: " "), groups.joined(separator: " "))
    }
    static func quantity(_ base: Int, mass: Bool) -> [String] {
        let unit = mass ? "quilo" : "litro", small = mass ? "grama" : "mililitro"
        let exact = "\(PortugueseNumbers.integer(base)) \(base == 1 ? small : small + "s")"
        let natural: String
        switch base {
        case 250: natural = "um quarto de " + unit
        case 500: natural = "meio " + unit
        case 750: natural = "três quartos de " + unit
        case 1000: natural = "um " + unit
        case 1500: natural = "um " + unit + " e meio"
        default:
            if base % 1000 == 0 { natural = "\(PortugueseNumbers.integer(base / 1000)) \(unit)s" }
            else if base > 1000 { natural = "\(PortugueseNumbers.integer(base / 1000)) \(base / 1000 == 1 ? unit : unit + "s") e \(PortugueseNumbers.integer(base % 1000)) \(small)s" }
            else { natural = exact }
        }
        return natural == exact ? [exact] : [natural, exact]
    }
    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput {
        let v = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tool {
        case .numbers, .numerals:
            switch input.mode {
            case "ordinal":
                let p = try NumberParsing.parse(v)
                guard !p.negative, p.fraction == nil else { throw ConversionError("Use a whole ordinal from 1 to 1000.") }
                let n = p.whole
                return ToolOutput(label: "Ordinal", headline: try PortugueseNumbers.ordinal(n, feminine: input.form == "f"), sub: "\(n).\(input.form == "f" ? "ª" : "º")", rows: [Expr(label: "Andar", text: "o \(try PortugueseNumbers.ordinal(n)) andar"), Expr(label: "Vez", text: "a \(try PortugueseNumbers.ordinal(n, feminine: true)) vez")])
            case "percent":
                let n = try PortugueseNumbers.number(v)
                return ToolOutput(label: "Percentagem", headline: n + " por cento", sub: v + " %", rows: [Expr(label: "Desconto", text: "um desconto de \(n) por cento")])
            case "degrees":
                let n = try PortugueseNumbers.number(v), p = try NumberParsing.parse(v)
                let words = n + (p.whole == 1 && p.fraction == nil ? " grau" : " graus")
                return ToolOutput(label: "Temperatura", headline: words, sub: v + " °C", rows: [Expr(label: "Como está o tempo?", text: "\(p.whole == 1 && p.fraction == nil ? "Está" : "Estão") \(words)")])
            case "floor":
                guard let n = Int(v), (-20...1000).contains(n) else { throw ConversionError("Use a floor from −20 to 1000.") }
                let words = n == 0 ? "o rés do chão" : n < 0 ? "a cave" : "o \(try PortugueseNumbers.ordinal(n)) andar"
                return ToolOutput(label: "Andar", headline: words, sub: n == 0 ? "R/C" : v, rows: [Expr(label: "Moro…", text: "Moro \(n < 0 ? "na cave" : n == 0 ? "no rés do chão" : "no " + (try PortugueseNumbers.ordinal(n)) + " andar")")])
            default:
                let p = try NumberParsing.parse(v)
                let rows = !p.negative && p.fraction == nil && (1...1000).contains(p.whole) ? [Expr(label: "Ordinal", text: try PortugueseNumbers.ordinal(p.whole))] : []
                return ToolOutput(label: "Em português", headline: try PortugueseNumbers.number(v), sub: v, rows: rows)
            }
        case .prices:
            let p = try Self.price(v)
            return ToolOutput(label: "Na caixa", headline: p.spoken, sub: p.display, rows: [Expr(label: "Por extenso", text: p.formal), Expr(label: "Pergunta", text: "Quanto custa? · Quanto é?")])
        case .time:
            let ex = PortugueseTime.expressions(hour: input.hour, minute: input.minute)
            return ToolOutput(label: "Que horas são?", headline: ex[0].text, sub: String(format: "%02d:%02d", input.hour, input.minute), rows: Array(ex.dropFirst()))
        case .date, .calendar:
            let w = PortugueseTime.date(input.date)
            return ToolOutput(label: "Que dia é hoje?", headline: w.full, sub: w.numeric, rows: [Expr(label: "Sem o ano", text: w.short), Expr(label: "Encontro", text: "Encontramo-nos no dia \(w.short)"), Expr(label: "Por escrito", text: w.written)])
        case .phone:
            let p = try Self.phone(v)
            return ToolOutput(label: "Em grupos", headline: p.grouped, sub: p.display, rows: [Expr(label: "Dígito a dígito", text: p.single), Expr(label: "O meu número", text: "O meu número é \(p.grouped)")])
        case .market:
            let quantity = try MarketQuantity(input)
            let words = try quantity.expressions(natural: Self.quantity(quantity.baseValue, mass: quantity.unit.isMass), language: .pt)
            return ToolOutput(label: "No mercado", headline: "Queria \(words[0]), por favor", sub: quantity.display, rows: words.dropFirst().map { Expr(label: "Ou então", text: $0) } + [Expr(label: "O vendedor", text: "Mais alguma coisa?"), Expr(label: "Resposta", text: "É tudo, obrigado")])
        case .years:
            guard let y = Int(v), (1...2999).contains(y) else { throw ConversionError("Use a year from 1 to 2999.") }
            let century = (y - 1) / 100 + 1
            return ToolOutput(label: "O ano", headline: PortugueseNumbers.integer(y), sub: v, rows: [Expr(label: "Em…", text: "em " + PortugueseNumbers.integer(y)), Expr(label: "Século", text: "o século \(NumberParsing.roman(century)) · \(century <= 10 ? try PortugueseNumbers.ordinal(century) : PortugueseNumbers.integer(century))")])
        case .verbs: throw ConversionError("Use the verb conjugator.")
        }
    }
    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation? { PortugueseConjugator.conjugate(verb, pronouns: pronouns) }
    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using r: inout R) -> DrillItem {
        switch tool {
        case .prices:
            let e = r.int(0...99), c = r.pick([0, 5, 10, 20, 50, 75, 90, 99])
            let p = try! Self.price(String(format: "%d,%02d", e, c))
            return DrillItem(spoken: p.formal, answer: p.display, placeholder: "12,50", kind: .price(euros: e, cents: c))
        case .time:
            let h = r.int(0...23), m = r.pick([0, 5, 10, 15, 20, 30, 40, 45, 50, 55])
            return DrillItem(spoken: PortugueseTime.everyday(hour: h, minute: m), answer: String(format: "%d:%02d", h, m), placeholder: "7:45", kind: .time(hour: h, minute: m))
        case .date, .calendar:
            let d = r.int(1...28), m = r.int(1...12)
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: m, day: d))!
            return DrillItem(spoken: PortugueseTime.date(date).short, answer: "\(d)/\(m)", placeholder: "8/3", kind: .dayMonth(day: d, month: m))
        case .phone:
            let digits = "9" + String(format: "%08d", r.int(0...99_999_999))
            return DrillItem(spoken: try! Self.phone(digits).single, answer: digits, placeholder: "912…", kind: .digits(digits))
        case .market:
            let g = r.pick([100, 200, 250, 500, 750, 1000, 1500, 2000])
            return DrillItem(spoken: Self.quantity(g, mass: true)[0], answer: "\(g) g", placeholder: "g", kind: .grams(g))
        case .years:
            let y = r.int(1100...2026)
            return DrillItem(spoken: PortugueseNumbers.integer(y), answer: "\(y)", placeholder: "1974", kind: .digits("\(y)"))
        default:
            let n = r.int(0...99_999)
            return DrillItem(spoken: PortugueseNumbers.integer(n), answer: "\(n)", placeholder: "123", kind: .digits("\(n)"))
        }
    }
    func realia<R: RandomNumberGenerator>(using r: inout R) -> Realia {
        switch r.int(0...5) {
        case 0:
            let h = r.int(0...23), m = r.pick([0, 15, 30, 45, 10, 40])
            let ex = PortugueseTime.expressions(hour: h, minute: m)
            var card = Realia(kind: .clock, question: "Que horas são?", answer: ex[0].text, alternative: ex[1].text, speech: ex[0].text)
            card.hour = h; card.minute = m
            return card
        case 1:
            let cents = r.int(100...2500), p = try! Self.price(String(format: "%d,%02d", cents / 100, cents % 100))
            var card = Realia(kind: .receipt, question: "Quanto é?", answer: p.spoken, alternative: p.formal, speech: p.formal)
            card.title = "CAFÉ DA PRAÇA"; card.lines = [("Pequeno-almoço", p.display)]; card.footer = ("TOTAL", p.display)
            return card
        case 2:
            let g = r.pick([250, 500, 750, 1000, 2000]), words = Self.quantity(g, mass: true)
            var card = Realia(kind: .priceTag, question: "Quanto quer?", answer: words[0], alternative: words.last, speech: "Queria \(words[0]) de queijo, por favor")
            card.title = "Queijo"; card.subtitle = "ao peso"; card.big = "\(g) g"
            return card
        case 3:
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: r.int(1...12), day: r.int(1...28)))!, words = PortugueseTime.date(date)
            var card = Realia(kind: .ticket, question: "Em que dia parte o comboio?", answer: words.full, alternative: words.short, speech: words.full)
            card.title = "Lisboa → Porto"; card.subtitle = "BILHETE · 2.ª CLASSE"; card.lines = [("DATA", words.numeric), ("PARTIDA", "14:30")]
            return card
        case 4:
            let number = "912 " + String(format: "%03d %03d", r.int(0...999), r.int(0...999)), words = try! Self.phone(number)
            var card = Realia(kind: .contact, question: "Qual é o número?", answer: words.grouped, alternative: words.single, speech: words.single)
            card.title = "Contacto"; card.big = number; card.subtitle = "Telemóvel"
            return card
        default:
            let y = r.pick([1143, 1415, 1500, 1640, 1910, 1974])
            var card = Realia(kind: .museum, question: "De que ano é?", answer: PortugueseNumbers.integer(y), alternative: "século \(NumberParsing.roman((y - 1) / 100 + 1))", speech: PortugueseNumbers.integer(y))
            card.title = "MUSEU DE HISTÓRIA"; card.subtitle = "Portugal"; card.big = "\(y)"
            return card
        }
    }
}

/// Complete, attested paradigms built from pinned UniMorph data; no network or guessed irregulars.
enum PortugueseConjugator {
    private struct File: Decodable { let verbs: [String: [String: [String]]] }
    private static let paradigms: [String: [String: [String]]] = {
        guard let url = Bundle.main.url(forResource: "verbs-pt", withExtension: "json", subdirectory: "Packs") ?? Bundle.main.url(forResource: "verbs-pt", withExtension: "json"),
              let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.verbs
    }()
    static func conjugate(_ input: String, pronouns: [String]) -> Conjugation? {
        let lemma = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let forms = paradigms[lemma] else { return nil }
        let order = [("prs", "Presente", "vós é sobretudo regional ou formal; vocês usa a 3.ª pessoa do plural"), ("pfv", "Pretérito perfeito", "ação concluída"), ("ipfv", "Imperfeito", "hábitos e descrição no passado"), ("fut", "Futuro", "amanhã"), ("cond", "Condicional", "hipótese"), ("sbjv", "Presente do conjuntivo", "desejo ou dúvida")]
        let tenses = order.compactMap { key, title, note -> ConjugationTense? in
            guard let f = forms[key], f.count == 6 else { return nil }
            return ConjugationTense(name: title, forms: f, note: note)
        }
        guard !tenses.isEmpty else { return nil }
        return Conjugation(lemma: lemma, kind: "Português europeu", pronouns: pronouns, tenses: tenses)
    }
}
