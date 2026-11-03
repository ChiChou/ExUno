import Foundation

enum NumberInputSuffix {
    static func text(for input: String, mode: String, romanInput: Bool = false) -> String? {
        let whole: Int?
        if romanInput, let roman = NumberParsing.fromRoman(input.trimmingCharacters(in: .whitespaces)) {
            whole = roman
        } else if let number = try? NumberParsing.parse(input), number.fraction == nil {
            whole = number.whole
        } else { whole = nil }

        switch mode {
        case "ordinal": return whole.map(ordinalEnding)
        case "percent": return "%"
        case "degrees": return " °C"
        case "floor": return (whole.map(ordinalEnding) ?? "") + " floor"
        default: return nil
        }
    }

    private static func ordinalEnding(_ number: Int) -> String {
        if (11...13).contains(number % 100) { return "th" }
        switch number % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
