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

    /// The widget shows a new word every half hour, walking the shuffled deck by clock time.
    static let cardInterval: TimeInterval = 1800

    static func card(at date: Date) -> WidgetCard? {
        let deck = deck(language)
        guard !deck.isEmpty else { return nil }
        return deck[Int(date.timeIntervalSince1970 / cardInterval) % deck.count]
    }

    /// Language and levels of the deck last written, so a relaunch doesn't reshuffle the word on screen.
    static var deckKey: String? {
        get { defaults.string(forKey: "deck.key") }
        set { defaults.set(newValue, forKey: "deck.key") }
    }

    static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

/// In-app links from the widgets and the app icon's quick actions: exuno://tool/prices, exuno://cards/412, exuno://today
enum DeepLink {
    static func tool(_ t: ToolKind) -> URL { URL(string: "exuno://tool/\(t.rawValue)")! }
    static let cards = URL(string: "exuno://cards")!
    /// Opens Cards roaming from this word.
    static func card(_ id: Int) -> URL { URL(string: "exuno://cards/\(id)")! }
    static let today = URL(string: "exuno://today")!
}
