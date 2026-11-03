import Foundation

enum MarketUnit: String, Identifiable {
    case gram = "g", etto, kilogram = "kg", millilitre = "ml", centilitre = "cl", decilitre = "dl", litre = "l"
    var id: String { rawValue }
    var label: String { self == .etto ? "etti" : self == .litre ? "L" : rawValue }
    var isMass: Bool { self == .gram || self == .etto || self == .kilogram }
    var scale: Int {
        switch self {
        case .gram, .millilitre: return 1
        case .centilitre: return 10
        case .etto, .decilitre: return 100
        case .kilogram, .litre: return 1000
        }
    }

    var presets: [String] {
        switch self {
        case .gram: return ["100", "200", "250", "500", "750", "1000", "1500", "2000"]
        case .etto: return ["1", "1,5", "2", "2,5", "3", "5"]
        case .kilogram: return ["0,25", "0,5", "0,75", "1", "1,5", "2"]
        case .millilitre: return ["100", "250", "330", "500", "750", "1000", "1500"]
        case .centilitre: return ["10", "20", "25", "33", "50", "75"]
        case .decilitre: return ["1", "2", "2,5", "3", "5", "7,5"]
        case .litre: return ["0,25", "0,33", "0,5", "0,75", "1", "1,5"]
        }
    }

    var defaultText: String { text(forBaseValue: isMass ? 250 : 500) }

    func text(forBaseValue value: Int) -> String {
        NSDecimalNumber(decimal: Decimal(value) / Decimal(scale)).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    func display(_ text: String) -> String {
        let singular = text.replacingOccurrences(of: ".", with: ",") == "1"
        return "\(text) \(self == .etto && singular ? "etto" : label)"
    }

    /// Switching within a dimension preserves the actual quantity, e.g. 250 g → 0,25 kg.
    func converted(_ text: String, to next: Self) -> String {
        guard isMass == next.isMass,
              let quantity = try? MarketQuantity(text: text, unit: self) else {
            return next.defaultText
        }
        return next.text(forBaseValue: quantity.baseValue)
    }
}

struct MarketQuantity {
    let unit: MarketUnit
    let baseValue: Int // whole grams or millilitres; the existing engines' exact representation
    let text: String
    var display: String { unit.display(text) }

    init(text: String, unit: MarketUnit) throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }),
              value.filter({ $0 == "," || $0 == "." }).count <= 1,
              value.last != ",", value.last != ".",
              let decimal = Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) else {
            throw ConversionError("Type a positive quantity with a decimal comma or point.")
        }
        let scaled = decimal * Decimal(unit.scale)
        guard scaled >= 1, scaled <= 100_000 else {
            throw ConversionError(unit.isMass ? "Use a weight from 1 g to 100 kg." : "Use a volume from 1 ml to 100 L.")
        }
        let base = NSDecimalNumber(decimal: scaled).intValue
        guard Decimal(base) == scaled else { throw ConversionError("Use whole grams or millilitres, or their exact equivalent in this unit.") }
        self.unit = unit
        baseValue = base
        self.text = unit.text(forBaseValue: base)
    }

    init(_ input: ToolInput) throws {
        guard let unit = MarketUnit(rawValue: input.unit) else { throw ConversionError("Choose a supported unit.") }
        try self.init(text: input.text, unit: unit)
    }

    /// Keep familiar spoken fractions while explicitly teaching the chosen unit as well.
    func expressions(natural: [String], language: LanguageCode) throws -> [String] {
        guard unit != .gram && unit != .millilitre else { return natural }
        let value = Decimal(baseValue) / Decimal(unit.scale)
        let singular = language == .fr ? value < 2 : value == 1
        let noun: String
        let number: String
        switch language {
        case .it:
            number = value == 1 ? "un" : try ItalianNumbers.number(text)
            switch unit {
            case .etto: noun = singular ? "etto" : "etti"
            case .kilogram: noun = singular ? "chilo" : "chili"
            case .centilitre: noun = singular ? "centilitro" : "centilitri"
            case .decilitre: noun = singular ? "decilitro" : "decilitri"
            default: noun = singular ? "litro" : "litri"
            }
        case .fr:
            number = try FrenchNumbers.number(text)
            switch unit {
            case .etto: throw ConversionError("Italian etti are not a French unit name.")
            case .kilogram: noun = singular ? "kilo" : "kilos"
            case .centilitre: noun = singular ? "centilitre" : "centilitres"
            case .decilitre: noun = singular ? "décilitre" : "décilitres"
            default: noun = singular ? "litre" : "litres"
            }
        case .es:
            number = SpanishNumbers.apocope(try SpanishNumbers.number(text))
            switch unit {
            case .etto: throw ConversionError("Italian etti are not a Spanish unit name.")
            case .decilitre: noun = singular ? "decilitro" : "decilitros"
            case .kilogram: noun = singular ? "kilo" : "kilos"
            case .centilitre: noun = singular ? "centilitro" : "centilitros"
            default: noun = singular ? "litro" : "litros"
            }
        case .la: return natural
        }
        let explicit = "\(number) \(noun)"
        var phrases = natural
        if unit == .centilitre || unit == .decilitre {
            phrases.insert(explicit, at: 0)
        } else if unit == .etto, let index = phrases.firstIndex(where: { $0.contains("etto") || $0.contains("etti") }) {
            phrases.insert(phrases.remove(at: index), at: 0)
        } else if unit == .kilogram, let index = phrases.firstIndex(where: { $0.contains("kilo") || $0.contains("chilo") || $0.contains("chili") }) {
            phrases.insert(phrases.remove(at: index), at: 0)
        }
        phrases.append(explicit)
        var seen = Set<String>()
        return phrases.filter { seen.insert($0).inserted }
    }
}
