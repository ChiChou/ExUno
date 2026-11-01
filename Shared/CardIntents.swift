import AppIntents
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Interactive buttons on the flashcard widget.
struct RevealCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Reveal the card"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.cardRevealed.toggle()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBridge.cardKind)
        #endif
        return .result()
    }
}

struct NextCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Next card"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.cardIndex += 1
        WidgetBridge.cardRevealed = false
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBridge.cardKind)
        #endif
        return .result()
    }
}
