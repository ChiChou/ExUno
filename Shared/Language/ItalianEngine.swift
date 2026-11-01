import Foundation

struct ItalianEngine: LanguageEngine {
    let code = LanguageCode.it
    let tools: [ToolKind] = [.numbers, .prices, .time, .date, .phone, .market, .years, .verbs]
    let pronouns = Conjugator.pronouns

    func title(_ tool: ToolKind) -> String {
        switch tool {
        case .numbers, .numerals: return "Numeri"
        case .prices: return "Prezzi"
        case .time: return "Ora"
        case .date, .calendar: return "Data"
        case .phone: return "Telefono"
        case .market: return "Al mercato"
        case .years: return "Anni e secoli"
        case .verbs: return "Verbi"
        }
    }

    var numberModes: [ChoiceOption] {
        [ChoiceOption(id: "number", label: "Numero"), ChoiceOption(id: "ordinal", label: "Ordinale"), ChoiceOption(id: "percent", label: "Percentuale"),
         ChoiceOption(id: "degrees", label: "Gradi"), ChoiceOption(id: "floor", label: "Piano")]
    }
    var ordinalForms: [ChoiceOption] { ItalianNumbers.OrdinalEnding.allCases.map { ChoiceOption(id: $0.rawValue, label: $0.label) } }

    func clockCard(_ now: Date) -> (question: String, headline: String, line: String) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return ("Che ore sono?", ItalianTime.everyday(hour: c.hour ?? 0, minute: c.minute ?? 0), "Oggi è " + ItalianTime.date(now).full)
    }

    func run(_ tool: ToolKind, _ input: ToolInput) throws -> ToolOutput {
        let v = input.text.trimmingCharacters(in: .whitespaces)
        switch tool {
        case .numbers, .numerals:
            switch input.mode {
            case "ordinal":
                let n = try ItalianNumbers.parse(v).whole
                let ending = ItalianNumbers.OrdinalEnding(rawValue: input.form) ?? .masculine
                return ToolOutput(label: "Ordinale", headline: try ItalianNumbers.ordinal(n, ending: ending), sub: "\(n)\(ending.sign)", rows: [
                    Expr(label: "Es. piano", text: "il \(try ItalianNumbers.ordinal(n)) piano"),
                    Expr(label: "Es. volta", text: "la \(try ItalianNumbers.ordinal(n, ending: .feminine)) volta"),
                    Expr(label: "Secolo", text: "\(ItalianNumbers.roman(n)) secolo")])
            case "percent":
                let p = try ItalianNumbers.percent(v)
                return ToolOutput(label: "Percentuale", headline: p.plain, sub: p.display, rows: [Expr(label: "Sconto", text: p.discount)])
            case "degrees":
                let t = try ItalianNumbers.temperature(v)
                return ToolOutput(label: "Temperatura", headline: t.words, sub: t.display, rows: [Expr(label: "Che tempo fa?", text: t.sentence)])
            case "floor":
                guard let n = Int(v.split(whereSeparator: { $0 == "," || $0 == "." }).first ?? "") else { throw ConversionError("Type a floor number.") }
                let f = ItalianNumbers.floor(n)
                return ToolOutput(label: "Piano", headline: f, sub: n == 0 ? "T" : "\(n)", rows: [Expr(label: "Abito…", text: "Abito al \(f.replacingOccurrences(of: "il ", with: ""))")])
            default:
                let n = try ItalianNumbers.number(v)
                var rows: [Expr] = []
                if let p = try? ItalianNumbers.parse(v), p.fraction == nil, (1...999_999).contains(p.whole), let o = try? ItalianNumbers.ordinal(p.whole) {
                    rows.append(Expr(label: "Ordinale", text: o))
                }
                return ToolOutput(label: "In italiano", headline: n, sub: v, rows: rows)
            }
        case .prices:
            let p = try ItalianNumbers.price(v)
            return ToolOutput(label: "Alla cassa", headline: p.spoken, sub: p.display, rows: [
                Expr(label: "Per esteso", text: p.formal), Expr(label: "Domanda", text: "Quanto costa? · Quant'è?")])
        case .time:
            let ex = ItalianTime.expressions(hour: input.hour, minute: input.minute)
            return ToolOutput(label: "Che ore sono?", headline: ex[0].text, sub: String(format: "%02d:%02d", input.hour, input.minute), rows: Array(ex.dropFirst()))
        case .date, .calendar:
            let w = ItalianTime.date(input.date)
            return ToolOutput(label: "Che giorno è?", headline: w.full, sub: w.numeric, rows: [
                Expr(label: "Breve", text: w.short), Expr(label: "Con l'anno", text: w.withYear),
                Expr(label: "Appuntamento", text: "Ci vediamo \(w.noYear)"), Expr(label: "Scritto", text: w.written)])
        case .phone:
            let p = try ItalianEveryday.phone(v)
            return ToolOutput(label: "A gruppi", headline: p.grouped, sub: p.display, rows: [
                Expr(label: "Cifra per cifra", text: p.single), Expr(label: "Il mio numero", text: "Il mio numero è \(p.grouped)")])
        case .market:
            guard let q = Int(v.filter(\.isNumber)) else { throw ConversionError("Type a quantity.") }
            let w = input.unit == "g" ? try ItalianEveryday.weight(grams: q) : try ItalianEveryday.volume(millilitres: q)
            return ToolOutput(label: "Al banco", headline: "Vorrei \(w[0]), per favore", sub: "\(q) \(input.unit)",
                              rows: w.dropFirst().map { Expr(label: "Oppure", text: $0) } + [Expr(label: "Risposta", text: "Basta così, grazie")])
        case .years:
            guard let y = Int(v.filter(\.isNumber)) else { throw ConversionError("Type a year.") }
            let yr = try ItalianTime.year(y)
            var rows = [Expr(label: "Nel…", text: yr.inYear)]
            if let c = yr.centuryName { rows.append(Expr(label: "Secolo (musei)", text: c)) }
            rows.append(Expr(label: "Secolo", text: "\(yr.century) · \(yr.centuryWords)"))
            if let d = yr.decade { rows.append(Expr(label: "Decennio", text: d)) }
            return ToolOutput(label: "L'anno", headline: yr.words, sub: "\(y)", rows: rows)
        case .verbs:
            throw ConversionError("Use conjugate(_:) for verbs.")
        }
    }

    func conjugate(_ verb: String, hint: VerbHint?) -> Conjugation? {
        guard let r = Conjugator.conjugate(verb) else { return nil }
        return Conjugation(lemma: r.lemma, kind: r.kind, pronouns: Conjugator.pronouns,
                           tenses: r.tenses.map { ConjugationTense(name: $0.name, forms: $0.forms, note: $0.note) })
    }

    func drill<R: RandomNumberGenerator>(_ tool: ToolKind, using r: inout R) -> DrillItem {
        switch tool {
        case .prices:
            let e = r.int(0...99), c = r.pick([0, 50, 20, 90, 10, 75, 99, 5])
            let p = try! ItalianNumbers.price("\(e),\(String(format: "%02d", c))")
            return DrillItem(spoken: r.chance(0.5) ? p.spoken : p.formal, answer: p.display, placeholder: "12,50", kind: .price(euros: e, cents: c))
        case .time:
            let h = r.int(0...23), m = r.pick([0, 15, 30, 45, 10, 20, 50, 5, 40, 25])
            let ex = ItalianTime.expressions(hour: h, minute: m)
            return DrillItem(spoken: ex[r.int(0...min(1, ex.count - 1))].text, answer: String(format: "%d:%02d", h, m), placeholder: "7:45", kind: .time(hour: h, minute: m))
        case .date, .calendar:
            let day = r.int(1...28), month = r.int(1...12)
            let w = ItalianTime.date(Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date())
            return DrillItem(spoken: r.chance(0.5) ? w.full : w.short, answer: "\(day)/\(month)", placeholder: "8/3", kind: .dayMonth(day: day, month: month))
        case .phone:
            let digits = "3\(r.int(2...9))" + String(format: "%08d", r.int(0...99_999_999))
            let p = try! ItalianEveryday.phone(digits)
            return DrillItem(spoken: r.chance(0.6) ? p.grouped : p.single, answer: p.display, placeholder: "333…", kind: .digits(digits))
        case .market:
            let g = r.pick([100, 150, 200, 250, 300, 500, 750, 1000, 1500, 2000])
            let w = (try? ItalianEveryday.weight(grams: g)) ?? ["\(g) grammi"]
            return DrillItem(spoken: r.pick(w), answer: "\(g) g", placeholder: "g", kind: .grams(g))
        case .years:
            let y = r.int(1100...2026)
            let yr = try! ItalianTime.year(y)
            return DrillItem(spoken: r.chance(0.5) ? yr.words : yr.inYear, answer: "\(y)", placeholder: "1485", kind: .digits("\(y)"))
        default:
            let roll = r.int(0...9)
            let n = roll < 4 ? r.int(0...99) : roll < 7 ? r.int(100...999) : r.int(1000...99_999)
            return DrillItem(spoken: ItalianNumbers.integer(n), answer: "\(n)", placeholder: "123", kind: .digits("\(n)"))
        }
    }

    private static let prices: [(String, Double)] = [("Caffè", 1.20), ("Cappuccino", 1.60), ("Cornetto", 1.30), ("Pizza margherita", 8.50), ("Spritz", 4.00), ("Gelato, due gusti", 3.50), ("Biglietto autobus", 1.50), ("Acqua naturale", 0.45), ("Panino", 5.50), ("Vino della casa", 7.00), ("Biglietto museo", 12.00), ("Pizza al taglio", 3.20)]
    private static let market: [(String, Int, String)] = [("Mozzarella", 250, "g"), ("Prosciutto cotto", 150, "g"), ("Parmigiano", 300, "g"), ("Pomodori", 500, "g"), ("Mele", 1000, "g"), ("Olive", 200, "g"), ("Latte", 1000, "ml"), ("Vino sfuso", 500, "ml"), ("Olio", 750, "ml"), ("Pesche", 1500, "g")]
    private static let routes = [("Roma Termini", "Firenze S.M.N."), ("Milano Centrale", "Venezia S. Lucia"), ("Napoli Centrale", "Bologna C.le"), ("Torino P. Nuova", "Genova P. Principe")]
    private static let works: [(String, String, Int)] = [("Botticelli", "La nascita di Venere", 1485), ("Leonardo da Vinci", "L'ultima cena", 1498), ("Michelangelo", "David", 1504), ("Caravaggio", "Bacco", 1596), ("Bernini", "Apollo e Dafne", 1625), ("Canova", "Amore e Psiche", 1793), ("Giotto", "Cappella degli Scrovegni", 1305)]

    func realia<R: RandomNumberGenerator>(using r: inout R) -> Realia {
        switch r.int(0...8) {
        case 0, 1:
            let items = Array(Self.prices.shuffled(using: &r).prefix(r.int(1...3)))
            let total = items.reduce(0) { $0 + $1.1 }
            let p = try! ItalianNumbers.price(String(format: "%.2f", total).replacingOccurrences(of: ".", with: ","))
            var x = Realia(kind: .receipt, question: "Quanto costa?", answer: p.spoken, alternative: p.formal, speech: "\(p.formal). \(p.spoken).")
            x.title = "BAR CENTRALE"; x.lines = items.map { ($0.0, RealiaFormat.euro($0.1)) }; x.footer = ("TOTALE", RealiaFormat.euro(total))
            return x
        case 2:
            let h = r.int(0...23), m = r.pick([0, 5, 10, 15, 20, 30, 40, 45, 50, 55])
            let ex = ItalianTime.expressions(hour: h, minute: m)
            var x = Realia(kind: .clock, question: "Che ore sono?", answer: ex[0].text, alternative: ex.dropFirst().prefix(2).map(\.text).joined(separator: " · "), speech: ex[0].text)
            x.hour = h; x.minute = m
            return x
        case 3:
            let d = Calendar.current.date(from: DateComponents(year: 2026, month: r.int(1...12), day: r.int(1...28))) ?? Date()
            let w = ItalianTime.date(d)
            let route = r.pick(Self.routes)
            var x = Realia(kind: .ticket, question: "Che giorno parte il treno?", answer: w.full, alternative: w.short, speech: w.full)
            x.title = "\(route.0) → \(route.1)"; x.lines = [("DATA", w.numeric), ("ORA", String(format: "%02d:%02d", r.int(6...20), r.pick([5, 10, 25, 40])))]; x.subtitle = "BIGLIETTO · 2ª CLASSE"
            return x
        case 4:
            let (name, q, unit) = r.pick(Self.market)
            let w = unit == "g" ? (try! ItalianEveryday.weight(grams: q)) : (try! ItalianEveryday.volume(millilitres: q))
            var x = Realia(kind: .priceTag, question: "Quanto ne vuole?", answer: "\(w[0]) di \(name.lowercased())", alternative: w.dropFirst().joined(separator: " · "), speech: "Vorrei \(w[0]) di \(name.lowercased()), per favore.")
            x.title = name; x.subtitle = unit == "g" ? "al banco" : "sfuso"; x.big = RealiaFormat.quantity(q, unit)
            return x
        case 5:
            let digits = "3\(r.pick(["3", "4", "2", "9"]))" + String(format: "%08d", r.int(0...99_999_999))
            let p = try! ItalianEveryday.phone(digits)
            var x = Realia(kind: .contact, question: "Qual è il numero?", answer: p.grouped, alternative: p.single, speech: p.grouped)
            x.title = r.pick(["Pizzeria da Nino", "Dott.ssa Rossi", "Farmacia Centrale", "Hotel Bellavista"]); x.big = p.display; x.subtitle = "Contatto"
            return x
        case 6:
            let (a, w, y) = r.pick(Self.works)
            let yr = try! ItalianTime.year(y)
            var x = Realia(kind: .museum, question: "Di che anno è?", answer: yr.inYear, alternative: "\(yr.centuryName ?? yr.century) · \(yr.century)", speech: "\(yr.inYear). \(yr.centuryName ?? yr.century).")
            x.title = a; x.subtitle = w; x.big = "\(y)"
            return x
        case 7:
            let n = r.int(0...7)
            let f = ItalianNumbers.floor(n)
            let al = "al " + f.replacingOccurrences(of: "il ", with: "")
            var x = Realia(kind: .elevator, question: "A che piano?", answer: al, alternative: f, speech: al)
            x.title = "PIANO"; x.big = n == 0 ? "T" : "\(n)"
            return x
        default:
            let t = r.int(-8...35)
            let tp = try! ItalianNumbers.temperature("\(t)")
            var x = Realia(kind: .pharmacy, question: "Quanti gradi ci sono?", answer: tp.words, alternative: tp.sentence, speech: tp.sentence)
            x.title = "+ FARMACIA +"; x.big = "\(t)°"
            return x
        }
    }
}

enum RealiaFormat {
    static func euro(_ v: Double) -> String { "€ " + String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") }
    static func quantity(_ q: Int, _ unit: String) -> String {
        if unit == "g" { return q >= 1000 ? (q % 1000 == 0 ? "\(q / 1000) kg" : String(format: "%.1f kg", Double(q) / 1000).replacingOccurrences(of: ".", with: ",")) : "\(q) g" }
        return q >= 1000 ? (q % 1000 == 0 ? "\(q / 1000) l" : String(format: "%.1f l", Double(q) / 1000).replacingOccurrences(of: ".", with: ",")) : "\(q) ml"
    }
}
