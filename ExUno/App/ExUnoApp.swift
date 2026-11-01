import SwiftUI
import WidgetKit

@main
struct ExUnoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var vocabulary = Vocabulary()
    @State private var grammar = GrammarCourses()
    @State private var progress = StudyProgress()
    @State private var speech = Speech()
    @State private var router = Router.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if progress.app.onboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environment(vocabulary)
            .environment(grammar)
            .environment(progress)
            .environment(speech)
            .environment(router)
            .onAppear { activate(progress.app.language) }
            .onChange(of: progress.app.language) { _, code in activate(code) }
            .onChange(of: vocabulary.isReady) { _, ready in if ready { WidgetSnapshot.refresh(vocab: vocabulary, progress: progress) } }
            .onOpenURL { router.open($0) }
        }
    }

    private func activate(_ code: LanguageCode) {
        if progress.language != code { progress.switchTo(code) }
        vocabulary.load(code)
        grammar.load(code)
        speech.stop()
        speech.language = code
        speech.rate = progress.app.rate
        speech.voiceIdentifier = progress.app.voices[code.rawValue] ?? ""
        WidgetBridge.language = code
        QuickActions.update(for: code)
        let vocab = vocabulary, prog = progress
        progress.onPackChange = { WidgetSnapshot.scheduleRefresh(vocab: vocab, progress: prog) }
        if vocabulary.isReady { WidgetSnapshot.refresh(vocab: vocabulary, progress: progress) }
    }
}

enum AppTab: Int { case today, cards, grammar, words, tools }

/// Tab selection plus deep links from widgets and the Today screen.
@Observable
final class Router {
    /// One router for the app, so quick actions arriving through the scene delegate reach the same tabs.
    static let shared = Router()
    var tab: AppTab = .today
    var tool: ToolKind?
    var grammar: GrammarRoute?
    /// A word from the Flashcard widget for Cards to roam from.
    var card: Int?

    func open(_ url: URL) {
        guard url.scheme == "exuno" else { return }
        switch url.host {
        case "tool":
            let t = ToolKind(rawValue: url.lastPathComponent)
            if t == .verbs { openGrammar(.verbs) } else { tab = .tools; tool = t }
        case "cards": tab = .cards; card = Int(url.lastPathComponent)
        case "grammar": tab = .grammar
        default: tab = .today
        }
    }

    func openGrammar(_ route: GrammarRoute) {
        tab = .grammar
        grammar = route
    }
}

extension StudyProgress {
    var language: LanguageCode { app.language }
    var engine: LanguageEngine { app.language.engine }
    var strings: UIStrings { app.language.strings }
}

struct RootView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        let s = progress.strings
        TabView(selection: $router.tab) {
            NavigationStack { TodayView() }
                .tag(AppTab.today)
                .tabItem { Label(s.today, systemImage: "sun.max") }
            NavigationStack { CardsView() }
                .tag(AppTab.cards)
                .tabItem { Label(s.cards, systemImage: "rectangle.on.rectangle") }
            GrammarTab()
                .tag(AppTab.grammar)
                .tabItem { Label(GrammarStrings.for(progress.language).grammar, systemImage: "character.book.closed") }
            NavigationStack { WordsView() }
                .tag(AppTab.words)
                .tabItem { Label(s.words, systemImage: "magnifyingglass") }
            ToolsView()
                .tag(AppTab.tools)
                .tabItem { Label(s.tools, systemImage: "list.number") }
        }
        .id(progress.language)   // switching language rebuilds every tab's state
        .tint(Theme.accent)
    }
}

/// Writes a shuffled set of words for the Flashcard widget into the App Group. The widget roams: it never
/// reads or writes study progress, it just shows random words from the selected levels.
enum WidgetSnapshot {
    private static var pending: DispatchWorkItem?

    /// Called on any progress change, debounced.
    static func scheduleRefresh(vocab: Vocabulary, progress: StudyProgress) {
        pending?.cancel()
        let work = DispatchWorkItem { refresh(vocab: vocab, progress: progress) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    /// Rebuilds only when the language or the selected levels changed: grading cards or relaunching the app
    /// (say from a tap on the widget) keeps the word on screen.
    static func refresh(vocab: Vocabulary, progress: StudyProgress) {
        guard let pack = vocab.current, pack.code == progress.language else { return }
        let levels = progress.settings.levels.isEmpty ? pack.defaultLevels : progress.settings.levels
        let key = "2|" + pack.code.rawValue + "|" + levels.joined(separator: ",")
        if key == WidgetBridge.deckKey && !WidgetBridge.deck(pack.code).isEmpty { return }
        WidgetBridge.deckKey = key
        let pool = pack.entries.filter { levels.contains($0.l) && !$0.isPhrase }
        // Half-hourly words: 240 of them last five days before the widget comes round again.
        let cards = pool.shuffled().prefix(240).map {
            WidgetCard(id: $0.i, word: $0.w, article: $0.article, translation: $0.t, example: $0.x, level: $0.l)
        }
        WidgetBridge.setDeck(cards, for: pack.code)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
