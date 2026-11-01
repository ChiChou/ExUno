import SwiftUI
import WidgetKit

@main
struct ExUnoWidgets: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        CardWidget()
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

// MARK: - Flashcard: a word and its meaning, a new one every half hour

struct CardEntry: TimelineEntry {
    let date: Date
    let language: LanguageCode
    let card: WidgetCard?
}

struct CardProvider: TimelineProvider {
    private static let sample = WidgetCard(id: 0, word: "piazza", article: "la", translation: "square, town square", example: "Ci vediamo in piazza alle sei.", level: "A1")
    func placeholder(in context: Context) -> CardEntry { CardEntry(date: Date(), language: .it, card: Self.sample) }
    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> Void) {
        completion(CardEntry(date: Date(), language: WidgetBridge.language, card: WidgetBridge.card(at: Date()) ?? Self.sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> Void) {
        let lang = WidgetBridge.language
        let step = WidgetBridge.cardInterval
        let slot = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 / step).rounded(.down) * step)
        let entries = (0..<48).map { i -> CardEntry in
            let d = i == 0 ? Date() : slot.addingTimeInterval(Double(i) * step)
            return CardEntry(date: d, language: lang, card: WidgetBridge.card(at: d))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct CardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.cardKind, provider: CardProvider()) { entry in
            CardWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.surface }
                .widgetURL(entry.card.map { DeepLink.card($0.id) } ?? DeepLink.cards)
        }
        .configurationDisplayName("Flashcard")
        .description("A word from your levels with its meaning, a new one every half hour. Tap to keep roaming from it in Cards. Nothing is recorded.")
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
                    Text(card.display).font(.headline).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
                    Text(card.translation).font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .systemSmall:
                VStack(alignment: .leading, spacing: 0) {
                    header(card)
                    Spacer(minLength: 6)
                    Text(card.display).font(Theme.display(22)).foregroundStyle(Theme.ink).minimumScaleFactor(0.5).lineLimit(2)
                    Text(card.translation).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.green)
                        .lineLimit(3).minimumScaleFactor(0.8).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            default:
                VStack(alignment: .leading, spacing: 0) {
                    header(card)
                    Spacer(minLength: 4)
                    Text(card.display).font(Theme.display(26)).foregroundStyle(Theme.ink).minimumScaleFactor(0.5).lineLimit(1)
                    Text(card.translation).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.green)
                        .lineLimit(2).minimumScaleFactor(0.8).padding(.top, 2)
                    if !card.example.isEmpty {
                        HStack(spacing: 8) {
                            Capsule().fill(Theme.accent.opacity(0.6)).frame(width: 2)
                            Text(card.example).font(.footnote).italic().foregroundStyle(Theme.ink2).lineLimit(2)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle").font(.title2).foregroundStyle(Theme.accent)
                Text("Open Ex Uno to load your cards").font(.caption).multilineTextAlignment(.center).foregroundStyle(Theme.ink2)
            }
        }
    }

    private func header(_ card: WidgetCard) -> some View {
        HStack(spacing: 6) {
            Text(card.level).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Theme.amber)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.amberSoft, in: Capsule())
            Spacer(minLength: 0)
            Monogram(code: entry.language, small: true)
        }
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
