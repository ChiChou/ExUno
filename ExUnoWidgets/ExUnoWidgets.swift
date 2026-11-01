import AppIntents
import SwiftUI
import WidgetKit

@main
struct ExUnoWidgets: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        CardWidget()
        ToolsWidget()
    }
}

// MARK: - Clock: the time and date, said in the current language

struct ClockEntry: TimelineEntry {
    let date: Date
    let language: LanguageCode
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date(), language: .it) }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), language: WidgetBridge.language))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let lang = WidgetBridge.language
        let cal = Calendar.current
        let start = cal.date(bySetting: .second, value: 0, of: Date()) ?? Date()
        let entries = (0..<60).compactMap { cal.date(byAdding: .minute, value: $0, to: start) }.map { ClockEntry(date: $0, language: lang) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.clockKind, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.slab }
                .widgetURL(DeepLink.today)
        }
        .configurationDisplayName("Clock")
        .description("The time and date, said in the language you're learning.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct ClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClockEntry
    var body: some View {
        let card = entry.language.engine.clockCard(entry.date)
        switch family {
        case .accessoryInline:
            Text(card.headline)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(card.question).font(.caption2).widgetAccentable()
                Text(card.headline).font(.headline).minimumScaleFactor(0.6).lineLimit(3)
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                Monogram(code: entry.language)
                Spacer(minLength: 0)
                Text(card.headline).font(Theme.display(17)).foregroundStyle(Theme.onSlab).minimumScaleFactor(0.6).lineLimit(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(card.question.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(Theme.onSlab.opacity(0.6)); Spacer(); Monogram(code: entry.language) }
                Spacer(minLength: 0)
                Text(card.headline).font(Theme.display(22)).foregroundStyle(Theme.onSlab).minimumScaleFactor(0.6).lineLimit(2)
                Text(card.line).font(.footnote).foregroundStyle(Theme.onSlab.opacity(0.75)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Flashcard: flip and advance right from the home screen

struct CardEntry: TimelineEntry {
    let date: Date
    let language: LanguageCode
    let card: WidgetCard?
    let revealed: Bool
}

struct CardProvider: TimelineProvider {
    private static let sample = WidgetCard(id: 0, word: "piazza", article: "la", translation: "square, town square", example: "Ci vediamo in piazza alle sei.", level: "A1")
    func placeholder(in context: Context) -> CardEntry { CardEntry(date: Date(), language: .it, card: Self.sample, revealed: true) }
    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> Void) {
        completion(CardEntry(date: Date(), language: WidgetBridge.language, card: WidgetBridge.currentCard() ?? Self.sample, revealed: true))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> Void) {
        let entry = CardEntry(date: Date(), language: WidgetBridge.language, card: WidgetBridge.currentCard(), revealed: WidgetBridge.cardRevealed)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct CardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.cardKind, provider: CardProvider()) { entry in
            CardWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.surface }
                .widgetURL(DeepLink.cards)
        }
        .configurationDisplayName("Flashcard")
        .description("Your next card. Tap the eye to flip it, the arrow for the next one.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CardEntry
    var body: some View {
        if let card = entry.card {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.display).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Text(card.translation).font(.caption).lineLimit(2)
                }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(card.level).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.amber); Spacer(); Monogram(code: entry.language, small: true) }
                    Spacer(minLength: 0)
                    Text(card.display).font(Theme.display(20)).foregroundStyle(Theme.ink).minimumScaleFactor(0.5).lineLimit(2)
                    Text(entry.revealed ? card.translation : " ").font(.caption).foregroundStyle(Theme.green).lineLimit(2)
                    Spacer(minLength: 0)
                    buttons
                }
            default:
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) { Monogram(code: entry.language, small: true); Text(card.level).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.amber) }
                        Text(card.display).font(Theme.display(24)).foregroundStyle(Theme.ink).minimumScaleFactor(0.5).lineLimit(2)
                        if entry.revealed {
                            Text(card.translation).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.green).lineLimit(2)
                            if !card.example.isEmpty { Text(card.example).font(.caption).foregroundStyle(Theme.ink2).lineLimit(2) }
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    VStack { buttons }
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle").font(.title2).foregroundStyle(Theme.blue)
                Text("Open Ex Uno to load your cards").font(.caption).multilineTextAlignment(.center).foregroundStyle(Theme.ink2)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(intent: RevealCardIntent()) {
                Image(systemName: entry.revealed ? "eye.slash" : "eye").font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 32).background(Theme.surface2, in: Capsule()).foregroundStyle(Theme.ink)
            }.buttonStyle(.plain)
            Button(intent: NextCardIntent()) {
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 32).background(Theme.blue, in: Capsule()).foregroundStyle(Theme.onBlue)
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - Tools launcher

struct ToolsEntry: TimelineEntry {
    let date: Date
    let language: LanguageCode
}

struct ToolsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ToolsEntry { ToolsEntry(date: Date(), language: .it) }
    func getSnapshot(in context: Context, completion: @escaping (ToolsEntry) -> Void) { completion(ToolsEntry(date: Date(), language: WidgetBridge.language)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ToolsEntry>) -> Void) {
        completion(Timeline(entries: [ToolsEntry(date: Date(), language: WidgetBridge.language)], policy: .never))
    }
}

struct ToolsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.toolsKind, provider: ToolsProvider()) { entry in
            ToolsWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.bg }
        }
        .configurationDisplayName("Tools")
        .description("Jump straight to a converter: prices, time, numbers and more.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ToolsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ToolsEntry
    var body: some View {
        let engine = entry.language.engine
        let tools = Array(engine.tools.prefix(family == .systemSmall ? 4 : 8))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: family == .systemSmall ? 2 : 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tools) { t in
                Link(destination: DeepLink.tool(t)) {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.onBlue)
                            .frame(width: 38, height: 38).background(Theme.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        if family != .systemSmall {
                            Text(engine.title(t)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Monogram: View {
    let code: LanguageCode
    var small = false
    var body: some View {
        Text(code.rawValue.uppercased())
            .font(.system(size: small ? 9 : 11, weight: .heavy, design: .rounded)).tracking(0.5)
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, small ? 5 : 7).padding(.vertical, small ? 2 : 3)
            .overlay(Capsule().stroke(Theme.ink2.opacity(0.5), lineWidth: 1))
    }
}
