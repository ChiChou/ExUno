import XCTest
@testable import ExUno

final class DailyChallengeChoicesTests: XCTestCase {
    private func entry(_ id: Int, _ word: String, _ translation: String, level: String = "A1") -> Entry {
        Entry(i: id, w: word, t: translation, l: level, p: "noun", x: "", e: "", z: 5)
    }

    private var entries: [Entry] {
        [entry(1, "casa", "house"), entry(2, "gatto", "cat"), entry(3, "libro", "book"),
         entry(4, "albero", "tree"), entry(5, "cane", "dog"), entry(6, "nave", "ship"),
         entry(7, "felice", "happy, glad"), entry(8, "contento", "glad")]
    }

    func testStableQuestionsWithDifferentWordsAndNoSharedSenses() throws {
        let first = DailyChallengeChoices.make(entries: entries, units: [], levels: ["A1"], day: 123, language: .it)
        let reordered = DailyChallengeChoices.make(entries: Array(entries.reversed()), units: [], levels: ["A1"], day: 123, language: .it)
        XCTAssertEqual(first, reordered)
        XCTAssertEqual(Set(first.keys), [0, 2, 4])
        XCTAssertEqual(Set(first.values.map(\.spoken)).count, 3)
        for question in first.values {
            XCTAssertEqual(question.options.count, 4)
            XCTAssertEqual(Set(question.options).count, 4)
            XCTAssertEqual(question.options.filter { $0 == question.answer }.count, 1)
            if question.kind == .word {
                XCTAssertFalse(question.options.contains("felice") && question.options.contains("contento"))
            } else {
                XCTAssertFalse(question.options.contains("happy, glad") && question.options.contains("glad"))
            }
        }
        XCTAssertNotEqual(first, DailyChallengeChoices.make(entries: entries, units: [], levels: ["A1"], day: 124, language: .it))
    }

    func testInsufficientOrWrongLevelMaterialFallsBackWithoutAmbiguousChoices() {
        XCTAssertTrue(DailyChallengeChoices.make(entries: Array(entries.prefix(3)), units: [], levels: ["A1"], day: 1, language: .it).isEmpty)
        XCTAssertTrue(DailyChallengeChoices.make(entries: entries, units: [], levels: ["B2"], day: 1, language: .it).isEmpty)
        let synonyms = (1...8).map { entry($0, "word\($0)", "house, home") }
        XCTAssertTrue(DailyChallengeChoices.make(entries: synonyms, units: [], levels: ["A1"], day: 1, language: .it).isEmpty)
    }

    func testGrammarKeepsEnglishContextAndSupportsAdvancedLevelFallback() throws {
        let item = GrammarItem(x: "Io ___ stanco.", a: "sono", o: ["sei", "sono", "è"], e: "I am tired.", h: nil, g: "io", k: "essere/0")
        let unit = GrammarUnit(id: "u", level: "B1", title: "", en: "", note: "", table: nil, items: [item])
        let question = try XCTUnwrap(DailyChallengeChoices.make(entries: [], units: [unit], levels: ["C1"], day: 1, language: .it)[3])
        XCTAssertEqual(question.kind, .gap)
        XCTAssertEqual(question.prompt, item.x)
        XCTAssertEqual(question.spoken, "Io sono stanco.")
        XCTAssertEqual(question.explanation, "I am tired.")
        XCTAssertEqual(question.answer, "sono")
        XCTAssertNil(DailyChallengeChoices.make(entries: [], units: [unit], levels: ["A1"], day: 1, language: .it)[3])
    }

    func testAllSevenBundledPacksSupplyEveryPracticeKind() throws {
        for language in LanguageCode.allCases {
            func data(_ name: String) throws -> Data {
                let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Packs")
                    ?? Bundle.main.url(forResource: name, withExtension: "json"))
                return try Data(contentsOf: url)
            }
            let pack = try JSONDecoder().decode(LanguagePackFile.self, from: data(language.rawValue))
            let grammar = try JSONDecoder().decode(GrammarCourseFile.self, from: data("grammar-" + language.rawValue))
            let plan = DailyChallengeChoices.make(entries: pack.entries, units: grammar.units,
                levels: pack.defaultLevels, day: 456, language: language)
            XCTAssertEqual(Set(plan.keys), [0, 2, 3, 4], language.rawValue)
            XCTAssertEqual(Set(plan.values.map(\.kind)), [.meaning, .word, .gap, .listening], language.rawValue)
            for question in plan.values {
                XCTAssertTrue(question.options.contains(question.answer), language.rawValue)
                XCTAssertEqual(question.options.count, Set(question.options).count, language.rawValue)
            }
            let roundTrip = try JSONDecoder().decode([Int: DailyChoiceQuestion].self, from: JSONEncoder().encode(plan))
            XCTAssertEqual(plan, roundTrip)
        }
    }
}
