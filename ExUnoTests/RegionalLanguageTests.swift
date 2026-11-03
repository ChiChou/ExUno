import XCTest
@testable import ExUno

final class RegionalLanguageTests: XCTestCase {
    func testExistingLanguageIDsAndChallengeSeedsStayStable() throws {
        XCTAssertEqual(Array(LanguageCode.allCases.prefix(5)), [.it, .es, .fr, .la, .pt])
        XCTAssertEqual(try JSONDecoder().decode(LanguageCode.self, from: Data("\"es\"".utf8)), .es)
        XCTAssertEqual(try JSONDecoder().decode(LanguageCode.self, from: Data("\"pt\"".utf8)), .pt)
        XCTAssertEqual(LanguageCode.esLatAm.rawValue, "es-419")
        XCTAssertEqual(LanguageCode.ptBR.rawValue, "pt-BR")
        XCTAssertEqual(LanguageCode.esLatAm.speechLocale, "es-MX")
        XCTAssertEqual(LanguageCode.ptBR.speechLocale, "pt-BR")
        XCTAssertEqual(LanguageCode.esLatAm.badge, "ES")
    }

    func testLatinAmericanConjugationUsesUstedesIncludingReflexives() throws {
        let engine = LanguageCode.esLatAm.engine
        let present = try XCTUnwrap(engine.conjugate("hablar", hint: nil)?.tenses.first { $0.name == "Presente" })
        XCTAssertEqual(engine.pronouns[4], "ustedes")
        XCTAssertEqual(try SpanishEngine.phone("5551234567").display, "555 123 4567")
        XCTAssertEqual(present.forms, ["hablo", "hablas", "habla", "hablamos", "hablan", "hablan"])
        let reflexive = try XCTUnwrap(engine.conjugate("levantarse", hint: nil)?.tenses.first)
        XCTAssertEqual(reflexive.forms[4], "se levantan")
        XCTAssertEqual(SpanishEngine().conjugate("hablar", hint: nil)?.tenses.first?.forms[4], "habláis")
    }

    func testBrazilianNumbersAndPronounsAreIndependentOfEuropean() throws {
        XCTAssertEqual(PortugueseNumbers.integer(16, brazilian: true), "dezesseis")
        XCTAssertEqual(PortugueseNumbers.integer(19, brazilian: true), "dezenove")
        XCTAssertEqual(PortugueseNumbers.integer(1_000_000_000, brazilian: true), "um bilhão")
        XCTAssertEqual(PortugueseNumbers.integer(1_000_000_000), "mil milhões")
        XCTAssertEqual(try PortugueseNumbers.number("17,16", brazilian: true), "dezessete vírgula dezesseis")
        let engine = LanguageCode.ptBR.engine
        let present = try XCTUnwrap(engine.conjugate("falar", hint: nil)?.tenses.first)
        XCTAssertEqual(engine.pronouns, ["eu", "você", "ele / ela", "nós", "vocês", "eles / elas"])
        XCTAssertEqual(present.forms, ["falo", "fala", "fala", "falamos", "falam", "falam"])
        XCTAssertEqual(engine.conjugate("falar", hint: nil)?.tenses.first { $0.name == "Pretérito perfeito" }?.forms[3], "falamos")
        XCTAssertEqual(try engine.run(.numbers, ToolInput(text: "0", mode: "floor")).headline, "o térreo")
        XCTAssertEqual(PortugueseTime.everyday(hour: 14, minute: 45, brazilian: true), "São duas e quarenta e cinco")
        XCTAssertEqual(try PortugueseEngine.phone("11912345678", brazilian: true).display, "11 91234 5678")
    }

    private func pack(_ code: LanguageCode) throws -> LanguagePackFile {
        let url = try XCTUnwrap(Bundle.main.url(forResource: code.rawValue, withExtension: "json", subdirectory: "Packs") ?? Bundle.main.url(forResource: code.rawValue, withExtension: "json"))
        return try JSONDecoder().decode(LanguagePackFile.self, from: Data(contentsOf: url))
    }

    func testRegionalVocabularyIsBundledAndDoesNotReassignSpanishIDs() throws {
        let spain = try pack(.es), latin = try pack(.esLatAm), brazil = try pack(.ptBR)
        XCTAssertEqual(latin.code, "es-419")
        XCTAssertEqual(Set(spain.entries.map(\.i)), Set(latin.entries.map(\.i)))
        let original = try XCTUnwrap(spain.entries.first { $0.w == "ordenador" && $0.p == "noun" })
        let adapted = try XCTUnwrap(latin.entries.first { $0.i == original.i })
        XCTAssertEqual(adapted.w, "computadora")
        XCTAssertEqual(adapted.a, "la")
        XCTAssertGreaterThan(brazil.entries.count, 15000)
        XCTAssertTrue(brazil.entries.contains { $0.w == "celular" })
        XCTAssertTrue(brazil.entries.contains { $0.w == "ônibus" })
        XCTAssertEqual(Set(brazil.entries.map(\.i)).count, brazil.entries.count)
    }

    func testRegionalDrillsAcceptTheirOwnAnswers() {
        for code in [LanguageCode.esLatAm, .ptBR] {
            var random = SeededRandom(seed: 100)
            for tool in code.engine.tools where tool != .verbs {
                for _ in 0..<25 {
                    let item = code.engine.drill(tool, using: &random)
                    XCTAssertFalse(item.spoken.isEmpty)
                    XCTAssertTrue(item.check(item.answer), "\(code) \(tool) \(item.answer)")
                }
            }
        }
    }
}
