import XCTest
@testable import ExUno

final class SpanishTests: XCTestCase {
    func testNumbers() {
        let cases: [(Int, String)] = [(1, "uno"), (16, "dieciséis"), (21, "veintiuno"), (22, "veintidós"), (31, "treinta y uno"), (100, "cien"),
                                      (101, "ciento uno"), (500, "quinientos"), (999, "novecientos noventa y nueve"), (1000, "mil"),
                                      (21_000, "veintiún mil"), (2026, "dos mil veintiséis"), (1_000_000, "un millón"), (2_500_000, "dos millones quinientos mil")]
        for (n, e) in cases { XCTAssertEqual(SpanishNumbers.integer(n), e, "\(n)") }
        XCTAssertEqual(try SpanishNumbers.number("3,14"), "tres coma catorce")
    }
    func testOrdinalsAndPrices() throws {
        XCTAssertEqual(try SpanishNumbers.ordinal(1), "primero")
        XCTAssertEqual(try SpanishNumbers.ordinal(3, apocopated: true), "tercer")
        XCTAssertEqual(try SpanishNumbers.ordinal(13), "decimotercero")
        XCTAssertEqual(try SpanishNumbers.ordinal(21, feminine: true), "vigésima primera")
        XCTAssertEqual(try SpanishEngine.price("12,50").spoken, "doce con cincuenta")
        XCTAssertEqual(try SpanishEngine.price("21").formal, "veintiún euros")
        XCTAssertEqual(try SpanishEngine.price("1,01").formal, "un euro con un céntimo")
    }
    func testTimeAndDates() {
        XCTAssertEqual(SpanishTime.everyday(hour: 13, minute: 15), "Es la una y cuarto")
        XCTAssertEqual(SpanishTime.everyday(hour: 7, minute: 45), "Son las ocho menos cuarto")
        XCTAssertEqual(SpanishTime.everyday(hour: 12, minute: 0), "Es mediodía")
        XCTAssertEqual(SpanishTime.everyday(hour: 18, minute: 40), "Son las siete menos veinte")
        let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 1))!
        XCTAssertEqual(SpanishTime.date(d, calendar: Calendar(identifier: .gregorian)).full, "domingo, uno de noviembre de dos mil veintiséis")
    }
    func testVerbs() {
        func f(_ v: String, _ t: String) -> [String] { SpanishConjugator.conjugate(v, pronouns: [])?.tenses.first { $0.name == t }?.forms ?? [] }
        XCTAssertEqual(f("hablar", "Presente"), ["hablo", "hablas", "habla", "hablamos", "habláis", "hablan"])
        XCTAssertEqual(f("pensar", "Presente"), ["pienso", "piensas", "piensa", "pensamos", "pensáis", "piensan"])
        XCTAssertEqual(f("poder", "Presente").first, "puedo")
        XCTAssertEqual(f("pedir", "Presente").first, "pido")
        XCTAssertEqual(f("conocer", "Presente").first, "conozco")
        XCTAssertEqual(f("buscar", "Pretérito indefinido").first, "busqué")
        XCTAssertEqual(f("tener", "Pretérito indefinido").first, "tuve")
        XCTAssertEqual(f("hacer", "Futuro").first, "haré")
        XCTAssertEqual(f("escribir", "Pretérito perfecto").first, "he escrito")
        XCTAssertEqual(f("levantarse", "Presente").first, "me levanto")
    }
}

final class FrenchTests: XCTestCase {
    func testNumbers() {
        let cases: [(Int, String)] = [(21, "vingt et un"), (22, "vingt-deux"), (70, "soixante-dix"), (71, "soixante et onze"), (77, "soixante-dix-sept"),
                                      (80, "quatre-vingts"), (81, "quatre-vingt-un"), (91, "quatre-vingt-onze"), (99, "quatre-vingt-dix-neuf"),
                                      (200, "deux cents"), (201, "deux cent un"), (280, "deux cent quatre-vingts"), (1000, "mille"),
                                      (2026, "deux mille vingt-six"), (80_000, "quatre-vingt mille"), (200_000, "deux cent mille"), (1_000_000, "un million")]
        for (n, e) in cases { XCTAssertEqual(FrenchNumbers.integer(n), e, "\(n)") }
        XCTAssertEqual(FrenchNumbers.swiss(97), "nonante-sept")
    }
    func testOrdinalsAndPrices() throws {
        XCTAssertEqual(try FrenchNumbers.ordinal(1), "premier")
        XCTAssertEqual(try FrenchNumbers.ordinal(1, feminine: true), "première")
        XCTAssertEqual(try FrenchNumbers.ordinal(5), "cinquième")
        XCTAssertEqual(try FrenchNumbers.ordinal(9), "neuvième")
        XCTAssertEqual(try FrenchNumbers.ordinal(21), "vingt et unième")
        XCTAssertEqual(try FrenchNumbers.ordinal(80), "quatre-vingtième")
        XCTAssertEqual(try FrenchEngine.price("12,50").spoken, "douze euros cinquante")
        XCTAssertEqual(try FrenchEngine.price("1").formal, "un euro")
    }
    func testTime() {
        XCTAssertEqual(FrenchTime.everyday(hour: 15, minute: 15), "Il est trois heures et quart")
        XCTAssertEqual(FrenchTime.everyday(hour: 7, minute: 45), "Il est huit heures moins le quart")
        XCTAssertEqual(FrenchTime.everyday(hour: 12, minute: 30), "Il est midi et demi")
        XCTAssertEqual(FrenchTime.everyday(hour: 1, minute: 30), "Il est une heure et demie")
        XCTAssertTrue(FrenchTime.expressions(hour: 15, minute: 15).contains { $0.text == "Il est quinze heures quinze" })
    }
    func testPhone() throws {
        XCTAssertEqual(try FrenchEngine.phone("06 12 34 56 78").grouped, "zéro six, douze, trente-quatre, cinquante-six, soixante-dix-huit")
    }
    func testVerbs() {
        func f(_ v: String, _ t: String) -> [String] { FrenchConjugator.conjugate(v, pronouns: [])?.tenses.first { $0.name == t }?.forms ?? [] }
        XCTAssertEqual(f("parler", "Présent"), ["je parle", "tu parles", "il parle", "nous parlons", "vous parlez", "ils parlent"])
        XCTAssertEqual(f("aimer", "Présent").first, "j'aime")
        XCTAssertEqual(f("manger", "Présent")[3], "nous mangeons")
        XCTAssertEqual(f("manger", "Imparfait")[3], "nous mangions")
        XCTAssertEqual(f("finir", "Présent")[3], "nous finissons")
        XCTAssertEqual(f("acheter", "Présent").first, "j'achète")
        XCTAssertEqual(f("aller", "Passé composé").first, "je suis allé(e)")
        XCTAssertEqual(f("avoir", "Futur simple").first, "j'aurai")
        XCTAssertEqual(f("se lever", "Présent").first, "je me lève")
    }
}

final class LatinTests: XCTestCase {
    func testCardinals() throws {
        let cases: [(Int, String)] = [(1, "ūnus"), (18, "duodēvīgintī"), (19, "ūndēvīgintī"), (21, "vīgintī ūnus"), (28, "duodētrīgintā"),
                                      (99, "nōnāgintā novem"), (100, "centum"), (753, "septingentī quīnquāgintā trēs"), (1000, "mīlle"), (2026, "duo mīlia vīgintī sex")]
        for (n, e) in cases { XCTAssertEqual(try LatinNumbers.cardinal(n), e, "\(n)") }
    }
    func testOrdinalsAndRoman() throws {
        XCTAssertEqual(try LatinNumbers.ordinal(3), "tertius")
        XCTAssertEqual(try LatinNumbers.ordinal(13, form: "acc"), "tertium decimum")
        XCTAssertEqual(try LatinNumbers.ordinal(19, form: "acc"), "ūndēvīcēsimum")
        XCTAssertEqual(NumberParsing.roman(2026), "MMXXVI")
        XCTAssertEqual(NumberParsing.fromRoman("MCMXCIV"), 1994)
        XCTAssertNil(NumberParsing.fromRoman("IIII"))
    }
    func testRomanCalendar() {
        XCTAssertEqual(RomanCalendar.date(day: 1, month: 11, year: 2026).full, "Kalendīs Novembribus")
        XCTAssertEqual(RomanCalendar.date(day: 15, month: 3, year: 2026).full, "Īdibus Mārtiīs")
        XCTAssertEqual(RomanCalendar.date(day: 4, month: 11, year: 2026).full, "prīdiē Nōnās Novembrēs")
        XCTAssertEqual(RomanCalendar.date(day: 3, month: 11, year: 2026).abbreviated, "a.d. III Non. Nov.")
        XCTAssertEqual(RomanCalendar.date(day: 25, month: 12, year: 2026).abbreviated, "a.d. VIII Kal. Ian.")
        XCTAssertEqual(RomanCalendar.date(day: 21, month: 4, year: 2026).abbreviated, "a.d. XI Kal. Mai.")
        XCTAssertEqual(RomanCalendar.date(day: 25, month: 2, year: 2028).abbreviated, "a.d. bis VI Kal. Mart.")
    }
    func testVerbs() {
        func f(_ v: String, _ hint: VerbHint?, _ t: String) -> [String] { LatinConjugator.conjugate(v, hint: hint, pronouns: [])?.tenses.first { $0.name == t }?.forms ?? [] }
        XCTAssertEqual(f("amō", VerbHint(forms: "-āre -āvī -ātum", verbClass: "1st Conjugation"), "Praesēns"), ["amō", "amās", "amat", "amāmus", "amātis", "amant"])
        XCTAssertEqual(f("amō", VerbHint(forms: "-āre -āvī -ātum", verbClass: "1st Conjugation"), "Perfectum").first, "amāvī")
        XCTAssertEqual(f("capiō", VerbHint(forms: "capere cēpī captum", verbClass: "3rd Conjugation -iō"), "Futūrum").first, "capiam")
        XCTAssertEqual(f("accēdō", VerbHint(forms: "-cēdere -cessī -cessum", verbClass: "3rd Conjugation -ō"), "Perfectum").first, "accessī")
        XCTAssertEqual(f("prohibeō", VerbHint(forms: "-ēre -uī -itum", verbClass: "2nd Conjugation"), "Perfectum").first, "prohibuī")
        XCTAssertEqual(f("sum", nil, "Praesēns"), ["sum", "es", "est", "sumus", "estis", "sunt"])
        XCTAssertEqual(f("absum", nil, "Perfectum").first, "āfuī")
        XCTAssertEqual(f("hortor", VerbHint(forms: "hortārī hortātus sum", verbClass: "Deponent"), "Praesēns")[1], "hortāris")
        XCTAssertEqual(f("sequor", VerbHint(forms: "sequī secūtus sum", verbClass: "Deponent"), "Perfectum").first, "secūtus sum")
    }
}

final class DrillTests: XCTestCase {
    func testChecks() {
        XCTAssertTrue(DrillItem(spoken: "", answer: "", placeholder: "", kind: .price(euros: 12, cents: 50)).check("12,5"))
        XCTAssertTrue(DrillItem(spoken: "", answer: "", placeholder: "", kind: .time(hour: 19, minute: 45)).check("7:45"))
        XCTAssertTrue(DrillItem(spoken: "", answer: "", placeholder: "", kind: .digits("29")).check("XXIX"))
        XCTAssertTrue(DrillItem(spoken: "", answer: "", placeholder: "", kind: .grams(500)).check("0,5"))
    }
    func testDailyChallengeIsStable() {
        for code in LanguageCode.allCases {
            XCTAssertEqual(code.engine.dailyChallenge(day: 20_000), code.engine.dailyChallenge(day: 20_000), code.rawValue)
            XCTAssertEqual(code.engine.dailyChallenge(day: 20_000).count, 5)
        }
    }
}

final class LanguageOrderTests: XCTestCase {
    func testPickersListLanguagesAlphabetically() {
        XCTAssertEqual(LanguageCode.alphabetical, [.es, .fr, .it, .la, .pt])
        XCTAssertEqual(LanguageCode.allCases, [.it, .es, .fr, .la, .pt], "case order seeds the daily challenge; don't reorder it")
    }
}

final class RoamingDeckTests: XCTestCase {
    @MainActor
    func testRoamingNeverTouchesProgress() async throws {
        let vocab = Vocabulary()
        vocab.load(.it)
        for _ in 0..<200 where !vocab.isReady && vocab.error == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        guard vocab.isReady else { throw XCTSkip("it.json is not in the bundle; run sh Scripts/prepare_data.sh") }
        let progress = StudyProgress()
        let before = progress.pack
        let deck = DeckEngine()
        deck.buildRoaming(vocab: vocab, settings: progress.settings)
        XCTAssertTrue(deck.roaming)
        for g in Array(repeating: [Grade.again, .good, .easy], count: 14).flatMap({ $0 }) {
            guard case .word = try XCTUnwrap(deck.current) else { return XCTFail("roaming shows words only") }
            XCTAssertTrue(deck.revealed)
            deck.advance(g, vocab: vocab, progress: progress)
        }
        XCTAssertNotNil(deck.current, "roaming refills and never runs out")
        XCTAssertFalse(deck.summaryDue)
        XCTAssertEqual(progress.pack, before, "roaming must not grade, schedule or log anything")
        let g = deck.generation
        deck.build(vocab: vocab, progress: progress)
        XCTAssertNotEqual(deck.generation, g, "a rebuild lets CardsView drop advances queued for the old deck")
    }
}
