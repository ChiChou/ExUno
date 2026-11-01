import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Data the app shares with its widgets through the App Group.
struct WidgetCard: Codable, Hashable {
    var id: Int
    var word: String
    var article: String
    var translation: String
    var example: String
    var level: String
    var display: String { article.isEmpty ? word : (article.hasSuffix("'") ? article + word : article + " " + word) }
}

enum WidgetBridge {
    static let appGroup = "group.me.chichou.ExUno"
    static let clockKind = "ExUnoClock"
    static let cardKind = "ExUnoCard"
    static let toolsKind = "ExUnoTools"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var language: LanguageCode {
        get { LanguageCode(rawValue: defaults.string(forKey: "language") ?? "") ?? .it }
        set { defaults.set(newValue.rawValue, forKey: "language") }
    }

    static func deck(_ code: LanguageCode) -> [WidgetCard] {
        guard let d = defaults.data(forKey: "deck.\(code.rawValue)"), let cards = try? JSONDecoder().decode([WidgetCard].self, from: d) else { return [] }
        return cards
    }
    static func setDeck(_ cards: [WidgetCard], for code: LanguageCode) {
        if let d = try? JSONEncoder().encode(cards) { defaults.set(d, forKey: "deck.\(code.rawValue)") }
    }

    static var cardIndex: Int {
        get { defaults.integer(forKey: "card.index") }
        set { defaults.set(newValue, forKey: "card.index") }
    }
    static var cardRevealed: Bool {
        get { defaults.bool(forKey: "card.revealed") }
        set { defaults.set(newValue, forKey: "card.revealed") }
    }

    static func currentCard() -> WidgetCard? {
        let deck = deck(language)
        guard !deck.isEmpty else { return nil }
        return deck[((cardIndex % deck.count) + deck.count) % deck.count]
    }

    static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

/// Deep links the widgets open: exuno://tool/prices, exuno://cards, exuno://today
enum DeepLink {
    static func tool(_ t: ToolKind) -> URL { URL(string: "exuno://tool/\(t.rawValue)")! }
    static let cards = URL(string: "exuno://cards")!
    static let today = URL(string: "exuno://today")!
}
