import Foundation

/// Turns numbers into spoken Italian. Pure functions, no UI.
enum ItalianNumbers {
    struct ConversionError: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
        init(_ message: String) { self.message = message }
    }

    static let units = ["zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove", "dieci",
                        "undici", "dodici", "tredici", "quattordici", "quindici", "sedici", "diciassette", "diciotto", "diciannove"]
    static let tens = ["", "", "venti", "trenta", "quaranta", "cinquanta", "sessanta", "settanta", "ottanta", "novanta"]

    private static func below100(_ n: Int) -> String {
        if n < 20 { return units[n] }
        var t = tens[n / 10]
        let u = n % 10
        if u == 1 || u == 8 { t.removeLast() }
        if u == 3 { return t + "tré" }
        return t + (u > 0 ? units[u] : "")
    }

    private static func below1000(_ n: Int) -> String {
        if n < 100 { return below100(n) }
        let h = n / 100, r = n % 100
        var s = h == 1 ? "cento" : units[h] + "cento"
        if (r >= 80 && r < 90) || r == 8 { s.removeLast() }
        if r == 3 { return s + "tré" }
        return s + (r > 0 ? below100(r) : "")
    }

    private static func below1e6(_ n: Int) -> String {
        if n < 1000 { return below1000(n) }
        let th = n / 1000, r = n % 1000
        let s = th == 1 ? "mille" : below1000(th).replacingOccurrences(of: "tré", with: "tre") + "mila"
        if r == 3 { return s + "tré" }
        return s + (r > 0 ? below1000(r) : "")
    }

    /// Whole numbers up to 999 999 999 999 999.
    static func integer(_ value: Int) -> String {
        if value < 0 { return "meno " + integer(-value) }
        if value < 1_000_000 { return below1e6(value) }
        var parts: [String] = []
        let bn = value / 1_000_000_000
        let rest = value % 1_000_000_000
        if bn > 0 { parts.append(bn == 1 ? "un miliardo" : below1000(bn) + " miliardi") }
        let mn = rest / 1_000_000
        let rest2 = rest % 1_000_000
        if mn > 0 { parts.append(mn == 1 ? "un milione" : below1000(mn) + " milioni") }
        if rest2 > 0 { parts.append(below1e6(rest2)) }
        return parts.joined(separator: " ")
    }

    struct Parsed {
        var negative: Bool
        var whole: Int
        var fraction: String?   // decimal digits as typed, e.g. "14" for 3,14
    }

    /// Parses "1.234", "1234,5", "-3" the way an Italian would read them.
    static func parse(_ input: String) throws -> Parsed {
        var s = input.filter { !$0.isWhitespace && $0 != "_" }
        guard !s.isEmpty else { throw ConversionError("Type a number to see it written in Italian.") }
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
            // Italian thousands grouping: 1.234 is one thousand two hundred thirty-four
            if separators == "." && frac.count == 3 && whole.count >= 1 && whole.count <= 3 {
                whole += frac
            } else {
                fraction = frac
            }
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

    /// "3,14" → "tre virgola quattordici"
    static func number(_ input: String) throws -> String {
        let p = try parse(input)
        var out = integer(p.whole)
        if let frac = p.fraction {
            if frac.hasPrefix("0") || frac.count > 3 {
                out += " virgola " + frac.compactMap { $0.wholeNumberValue }.map { units[$0] }.joined(separator: " ")
            } else {
                out += " virgola " + integer(Int(frac) ?? 0)
            }
        }
        let nonzero = p.whole != 0 || (p.fraction?.contains(where: { $0 != "0" }) ?? false)
        return (p.negative && nonzero ? "meno " : "") + out
    }

    enum OrdinalEnding: String, CaseIterable, Identifiable {
        case masculine = "o", feminine = "a", masculinePlural = "i", femininePlural = "e"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .masculine: return "il primo"
            case .feminine: return "la prima"
            case .masculinePlural: return "i primi"
            case .femininePlural: return "le prime"
            }
        }
        var sign: String { (self == .feminine || self == .femininePlural) ? "ª" : "º" }
    }

    /// 1 → primo, 23 → ventitreesimo
    static func ordinal(_ n: Int, ending: OrdinalEnding = .masculine) throws -> String {
        guard n >= 1 && n <= 999_999 else { throw ConversionError("Use a whole number from 1 to 999 999.") }
        let irregular = [1: "prim", 2: "second", 3: "terz", 4: "quart", 5: "quint", 6: "sest", 7: "settim", 8: "ottav", 9: "non", 10: "decim"]
        if let stem = irregular[n] { return stem + ending.rawValue }
        let c = integer(n).replacingOccurrences(of: " ", with: "")
        let stem: String
        if c.hasSuffix("tré") { stem = String(c.dropLast(3)) + "treesim" }
        else if c.hasSuffix("sei") { stem = c + "esim" }
        else if c.hasSuffix("mille") { stem = String(c.dropLast(5)) + "millesim" }
        else if c.hasSuffix("mila") { stem = String(c.dropLast(4)) + "millesim" }
        else if c.hasSuffix("dieci") { stem = String(c.dropLast(5)) + "decim" }
        else { stem = String(c.dropLast()) + "esim" }
        return stem + ending.rawValue
    }

    static func roman(_ value: Int) -> String {
        var n = value, s = ""
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        for (v, r) in table { while n >= v { s += r; n -= v } }
        return s
    }

    struct Price {
        var whole: Int
        var cents: Int
        var formal: String   // dodici euro e cinquanta centesimi
        var spoken: String   // dodici e cinquanta
        var display: String  // € 12,50
        var amount: Double { Double(whole) + Double(cents) / 100 }
    }

    static func price(_ input: String) throws -> Price {
        let p = try parse(input)
        var cents = 0
        if let f = p.fraction {
            guard f.count <= 2 else { throw ConversionError("Prices have at most two decimal places.") }
            cents = Int(f.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        }
        let euroWord = p.whole == 1 ? "un euro" : integer(p.whole) + " euro"
        let centWord = cents == 1 ? "un centesimo" : integer(cents) + " centesimi"
        let formal: String, spoken: String
        if p.whole == 0 { formal = centWord; spoken = centWord }
        else if cents == 0 { formal = euroWord; spoken = euroWord }
        else {
            formal = "\(euroWord) e \(centWord)"
            spoken = "\(p.whole == 1 ? "uno" : integer(p.whole)) e \(integer(cents))"
        }
        let display = "€ \(p.whole.formatted(.number.locale(Locale(identifier: "it_IT")))),\(String(format: "%02d", cents))"
        return Price(whole: p.whole, cents: cents, formal: formal, spoken: spoken, display: display)
    }

    struct Percent { var plain: String; var discount: String; var display: String }
    static func percent(_ input: String) throws -> Percent {
        let n = try number(input)
        return Percent(plain: "\(n) per cento", discount: "uno sconto del \(n) per cento", display: input.replacingOccurrences(of: ".", with: ",") + "%")
    }

    struct Temperature { var words: String; var sentence: String; var display: String }
    static func temperature(_ input: String) throws -> Temperature {
        let cleaned = input.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned) else { throw ConversionError("Type a temperature.") }
        let absText = try number(String(abs(v)).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ".", with: ","))
        let words: String
        if v < 0 { words = "meno \(absText) gradi" }
        else if abs(v) == 1 { words = "un grado" }
        else { words = "\(absText) gradi" }
        return Temperature(words: words, sentence: "Ci sono \(words)", display: input.replacingOccurrences(of: ".", with: ",") + " °C")
    }

    /// 0 → il piano terra, 3 → il terzo piano, -1 → il piano interrato
    static func floor(_ n: Int) -> String {
        if n == 0 { return "il piano terra" }
        if n < 0 { return n == -1 ? "il piano interrato" : "il \((try? ordinal(-n)) ?? String(-n)) piano interrato" }
        return "il \((try? ordinal(n)) ?? String(n)) piano"
    }
}
