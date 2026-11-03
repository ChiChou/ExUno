import XCTest
@testable import ExUno

final class PortugueseTests: XCTestCase {
    func testEuropeanNumbersAndLongScale() throws {
        let cases: [(Int, String)] = [(0, "zero"), (16, "dezasseis"), (17, "dezassete"), (19, "dezanove"), (21, "vinte e um"),
            (100, "cem"), (101, "cento e um"), (200, "duzentos"), (1000, "mil"), (1001, "mil e um"),
            (1100, "mil e cem"), (1123, "mil cento e vinte e três"), (2026, "dois mil e vinte e seis"),
            (1_000_000, "um milhão"), (1_000_000_000, "mil milhões"), (1_000_000_000_000, "um bilião")]
        for (n, expected) in cases { XCTAssertEqual(PortugueseNumbers.integer(n), expected, "\(n)") }
        XCTAssertEqual(PortugueseNumbers.integer(222, feminine: true), "duzentas e vinte e duas")
        XCTAssertEqual(try PortugueseNumbers.number("-0,05"), "menos zero vírgula zero cinco")
        XCTAssertEqual(try PortugueseNumbers.number("3,14"), "três vírgula catorze")
        XCTAssertEqual(try PortugueseNumbers.ordinal(23, feminine: true), "vigésima terceira")
        XCTAssertThrowsError(try PortugueseNumbers.ordinal(0))
    }

    func testHoursAgreeAndCrossMidnight() {
        XCTAssertEqual(PortugueseTime.everyday(hour: 1, minute: 15), "É uma e um quarto")
        XCTAssertEqual(PortugueseTime.everyday(hour: 14, minute: 30), "São duas e meia")
        XCTAssertEqual(PortugueseTime.everyday(hour: 23, minute: 45), "É meia-noite menos um quarto")
        XCTAssertEqual(PortugueseTime.everyday(hour: 12, minute: 30), "É meio-dia e meia")
        XCTAssertEqual(PortugueseTime.expressions(hour: 1, minute: 0)[1].text, "É uma hora")
        XCTAssertEqual(PortugueseTime.expressions(hour: 12, minute: 0)[2].text, "Encontramo-nos ao meio-dia")
    }

    func testDatesPricesPhoneAndUnits() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        XCTAssertEqual(PortugueseTime.date(date, calendar: calendar).full, "domingo, primeiro de novembro de dois mil e vinte e seis")
        XCTAssertEqual(try PortugueseEngine.price("12,50").formal, "doze euros e cinquenta cêntimos")
        XCTAssertEqual(try PortugueseEngine.price("1,01").formal, "um euro e um cêntimo")
        XCTAssertEqual(try PortugueseEngine.price("0,05").formal, "cinco cêntimos")
        XCTAssertThrowsError(try PortugueseEngine.price("-1"))
        XCTAssertEqual(try PortugueseEngine.phone("912 003 456").grouped, "novecentos e doze, zero zero três, quatrocentos e cinquenta e seis")
        let input = ToolInput(text: "25", unit: "cl")
        let output = try PortugueseEngine().run(.market, input)
        XCTAssertEqual(output.headline, "Queria vinte e cinco centilitros, por favor")
        XCTAssertTrue(output.rows.contains { $0.text == "um quarto de litro" })
        XCTAssertEqual(try PortugueseEngine().run(.numbers, ToolInput(text: "0", mode: "floor")).headline, "o rés do chão")
    }

    func testBundledVocabularyAndConjugationsArePresent() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "pt", withExtension: "json", subdirectory: "Packs") ?? Bundle.main.url(forResource: "pt", withExtension: "json"))
        let pack = try JSONDecoder().decode(LanguagePackFile.self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(pack.entries.count, 8000)
        XCTAssertEqual(Set(pack.entries.map(\.i)).count, pack.entries.count)
        XCTAssertTrue(pack.availableMarketUnits.contains(.decilitre))
        XCTAssertTrue(pack.entries.contains { $0.w == "telemóvel" })
        XCTAssertEqual(LanguageCode.pt.speechLocale, "pt-PT")
        func forms(_ verb: String, _ tense: String) -> [String]? {
            PortugueseEngine().conjugate(verb, hint: nil)?.tenses.first { $0.name == tense }?.forms
        }
        XCTAssertEqual(forms("falar", "Presente"), ["falo", "falas", "fala", "falamos", "falais", "falam"])
        XCTAssertEqual(forms("falar", "Pretérito perfeito")?[3], "falámos")
        XCTAssertEqual(forms("ir", "Presente")?[3], "vamos")
        XCTAssertEqual(forms("estar", "Presente")?[3], "estamos")
        XCTAssertEqual(forms("estar", "Futuro")?[1], "estarás")
        XCTAssertEqual(forms("estar", "Imperfeito")?[5], "estavam")
        XCTAssertEqual(forms("haver", "Presente")?[3], "havemos")
        XCTAssertEqual(forms("fazer", "Presente")?.first, "faço")
        XCTAssertEqual(forms("ter", "Presente do conjuntivo")?.first, "tenha")
        XCTAssertNil(PortugueseEngine().conjugate("not a verb", hint: nil))
    }

    func testDrillsAcceptTheirAnswersAndRealiaIsPortuguese() throws {
        var rng = SeededRandom(seed: 2026)
        let engine = PortugueseEngine()
        for tool in engine.tools where tool != .verbs {
            for _ in 0..<30 {
                let item = engine.drill(tool, using: &rng)
                XCTAssertFalse(item.spoken.isEmpty)
                XCTAssertTrue(item.check(item.answer), "\(tool): \(item.answer)")
            }
        }
        for _ in 0..<30 {
            let card = engine.realia(using: &rng)
            XCTAssertFalse(card.question.isEmpty)
            XCTAssertFalse(card.speech.isEmpty)
        }
        XCTAssertEqual(engine.dailyChallenge(day: 100), engine.dailyChallenge(day: 100))
    }
}
