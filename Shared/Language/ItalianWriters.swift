import Foundation

/// Time of day, dates, years and centuries.
enum ItalianTime {
    static let weekdays = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
    static let months = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]

    private static func hourPhrase(_ hour: Int, landmarks: Bool, h24: Bool) -> String {
        let h = ((hour % 24) + 24) % 24
        if landmarks {
            if h == 0 { return "mezzanotte" }
            if h == 12 { return "mezzogiorno" }
        }
        let spoken = h24 ? h : (h % 12 == 0 ? 12 : h % 12)
        return spoken == 1 ? "l'una" : "le " + ItalianNumbers.integer(spoken)
    }

    private static func sentence(_ hour: Int, _ suffix: String, landmarks: Bool, h24: Bool = false) -> String {
        let p = hourPhrase(hour, landmarks: landmarks, h24: h24)
        let singular = p == "l'una" || p == "mezzogiorno" || p == "mezzanotte"
        return "\(singular ? "È" : "Sono") \(p)\(suffix)"
    }

    private static func atPhrase(_ hour: Int) -> String {
        let p = hourPhrase(hour, landmarks: true, h24: false)
        switch p {
        case "l'una": return "all'una"
        case "mezzogiorno": return "a mezzogiorno"
        case "mezzanotte": return "a mezzanotte"
        default: return "alle " + String(p.dropFirst(3))
        }
    }

    /// Several ways to say a clock time; the first is the everyday one.
    static func expressions(hour: Int, minute m: Int) -> [ItalianExpression] {
        var out: [ItalianExpression] = []
        func push(_ label: String, _ text: String) { if !out.contains(where: { $0.text == text }) { out.append(ItalianExpression(label: label, text: text)) } }
        let everyday: String
        switch m {
        case 0: everyday = sentence(hour, " in punto", landmarks: true)
        case 15: everyday = sentence(hour, " e un quarto", landmarks: true)
        case 30: everyday = sentence(hour, " e mezza", landmarks: true)
        case 45: everyday = sentence(hour + 1, " meno un quarto", landmarks: true)
        case 40...59: everyday = sentence(hour + 1, " meno \(ItalianNumbers.integer(60 - m))", landmarks: true)
        default: everyday = sentence(hour, " e \(ItalianNumbers.integer(m))", landmarks: true)
        }
        push("Everyday", everyday)
        push("Also", m == 0 ? sentence(hour, "", landmarks: true) : sentence(hour, " e \(ItalianNumbers.integer(m))", landmarks: true))
        if hour >= 13 { push("24-hour clock", sentence(hour, m > 0 ? " e \(ItalianNumbers.integer(m))" : "", landmarks: false, h24: true)) }
        let suffix: String
        switch m {
        case 0: suffix = ""
        case 15: suffix = " e un quarto"
        case 30: suffix = " e mezza"
        case 45: suffix = " meno un quarto"
        case 40...59: suffix = " meno \(ItalianNumbers.integer(60 - m))"
        default: suffix = " e \(ItalianNumbers.integer(m))"
        }
        let at = m >= 40 ? atPhrase(hour + 1) : atPhrase(hour)
        push("A che ora?", "Ci vediamo \(at)\(suffix)")
        return out
    }

    static func everyday(hour: Int, minute: Int) -> String { expressions(hour: hour, minute: minute).first?.text ?? "" }

    struct DateWords {
        var full: String      // domenica primo novembre duemilaventisei
        var short: String     // il primo novembre / l'otto marzo
        var withYear: String
        var weekday: String
        var month: String
        var year: String
        var numeric: String   // 01/11/2026
        var written: String   // 1º novembre 2026
        var noYear: String { full.replacingOccurrences(of: " " + year, with: "") }
    }

    static func date(_ date: Date, calendar: Calendar = .current) -> DateWords {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: date)
        let wd = weekdays[(c.weekday ?? 1) - 1], d = c.day ?? 1, mo = months[(c.month ?? 1) - 1], y = c.year ?? 2000
        let dayWord = d == 1 ? "primo" : ItalianNumbers.integer(d)
        let article = d == 1 ? "il primo" : (d == 8 || d == 11) ? "l'" + dayWord : "il " + dayWord
        let yearWord = ItalianNumbers.integer(y)
        return DateWords(
            full: "\(wd) \(dayWord) \(mo) \(yearWord)",
            short: "\(article) \(mo)",
            withYear: "\(article) \(mo) \(yearWord)",
            weekday: wd, month: mo, year: yearWord,
            numeric: String(format: "%02d/%02d/%d", d, c.month ?? 1, y),
            written: "\(d == 1 ? "1º" : String(d)) \(mo) \(y)")
    }

    struct YearWords {
        var words: String
        var inYear: String
        var century: String        // XV secolo
        var centuryWords: String   // quindicesimo secolo
        var centuryName: String?   // il Quattrocento
        var decade: String?        // gli anni Ottanta
    }

    private static let centuryNames = [12: "il Duecento", 13: "il Trecento", 14: "il Quattrocento", 15: "il Cinquecento", 16: "il Seicento", 17: "il Settecento", 18: "l'Ottocento", 19: "il Novecento", 20: "il Duemila"]
    private static let decades = ["Dieci", "Venti", "Trenta", "Quaranta", "Cinquanta", "Sessanta", "Settanta", "Ottanta", "Novanta"]

    static func year(_ y: Int) throws -> YearWords {
        guard y >= 1 && y <= 2999 else { throw ItalianNumbers.ConversionError("Use a year from 1 to 2999.") }
        let centuryNumber = (y - 1) / 100 + 1
        let dec = (y % 100) / 10
        return YearWords(
            words: ItalianNumbers.integer(y),
            inYear: "nel " + ItalianNumbers.integer(y),
            century: "\(ItalianNumbers.roman(centuryNumber)) secolo",
            centuryWords: "\((try? ItalianNumbers.ordinal(centuryNumber)) ?? "") secolo",
            centuryName: centuryNames[y / 100],
            decade: (dec >= 1 && y >= 1900) ? "gli anni \(decades[dec - 1])" : nil)
    }
}

/// Phone numbers, market quantities.
enum ItalianEveryday {
    struct Phone { var single: String; var grouped: String; var display: String }

    private static func digitWords(_ s: String) -> String {
        s.compactMap { $0.wholeNumberValue }.map { ItalianNumbers.units[$0] }.joined(separator: " ")
    }

    static func phone(_ input: String) throws -> Phone {
        let digits = input.filter { $0.isNumber }
        guard digits.count >= 3 else { throw ItalianNumbers.ConversionError("Type at least three digits.") }
        let chars = Array(digits)
        var prefixLen: Int
        if chars[0] == "3" { prefixLen = 3 }
        else if chars[0] == "0" { prefixLen = (chars.count > 1 && (chars[1] == "6" || chars[1] == "2")) ? 2 : 3 }
        else { prefixLen = 3 }
        if digits.count <= 4 { prefixLen = 0 }
        let prefix = String(chars[0..<prefixLen])
        let rest = Array(chars[prefixLen...])
        var groups: [String] = []
        var i = 0
        while i < rest.count {
            let size = (rest.count - i) == 1 ? 1 : 2
            groups.append(String(rest[i..<(i + size)]))
            i += size
        }
        let groupWords: [String] = groups.map { g in
            if g.count == 1 { return ItalianNumbers.units[Int(g) ?? 0] }
            if g.hasPrefix("0") { return "zero " + digitWords(String(g.dropFirst())) }
            return ItalianNumbers.integer(Int(g) ?? 0)
        }
        let prefixWords = prefix.isEmpty ? "" : digitWords(prefix)
        let grouped = ([prefixWords] + groupWords).filter { !$0.isEmpty }.joined(separator: ", ")
        let display = ([prefix] + groups).filter { !$0.isEmpty }.joined(separator: " ")
        return Phone(single: digitWords(digits), grouped: grouped, display: display)
    }

    /// Grams → ways to ask at the counter; the first is the most natural.
    static func weight(grams g: Int) throws -> [String] {
        guard g > 0 && g <= 100_000 else { throw ItalianNumbers.ConversionError("Use a weight from 1 g to 100 kg.") }
        var out: [String] = []
        let n = ItalianNumbers.integer
        switch g {
        case 500: out = ["mezzo chilo", "cinque etti"]
        case 1000: out = ["un chilo"]
        case 250: out = ["due etti e mezzo", "un quarto di chilo"]
        case 750: out = ["sette etti e mezzo", "tre quarti di chilo"]
        case 1500: out = ["un chilo e mezzo"]
        default:
            if g % 1000 == 0 { out = ["\(n(g / 1000)) chili"] }
            else if g > 1000 && g % 1000 == 500 { out = ["\(n(g / 1000)) chili e mezzo"] }
            else if g < 1000 && g % 100 == 0 { out = [g == 100 ? "un etto" : "\(n(g / 100)) etti"] }
            else if g < 1000 && g % 50 == 0 { out = [g == 150 ? "un etto e mezzo" : "\(n(g / 100)) etti e mezzo"] }
        }
        if g < 1000 { let grams = "\(n(g)) grammi"; if !out.contains(grams) { out.append(grams) } }
        if g >= 1000 && out.isEmpty {
            let kg = g / 1000, rest = g % 1000
            out = ["\(kg == 1 ? "un chilo" : n(kg) + " chili") e \(n(rest)) grammi", "\(n(g)) grammi"]
        }
        return out
    }

    static func volume(millilitres ml: Int) throws -> [String] {
        guard ml > 0 && ml <= 100_000 else { throw ItalianNumbers.ConversionError("Use a volume from 1 ml to 100 l.") }
        let n = ItalianNumbers.integer
        switch ml {
        case 500: return ["mezzo litro"]
        case 250: return ["un quarto di litro", "un quartino"]
        case 750: return ["tre quarti di litro"]
        case 1000: return ["un litro"]
        case 1500: return ["un litro e mezzo"]
        default:
            if ml % 1000 == 0 { return ["\(n(ml / 1000)) litri"] }
            if ml % 1000 == 500 { return ["\(n(ml / 1000)) litri e mezzo"] }
            if ml < 1000 { return ["\(n(ml)) millilitri"] }
            return ["\(n(ml / 1000)) litri e \(n(ml % 1000)) millilitri"]
        }
    }
}
