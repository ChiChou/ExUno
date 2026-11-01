import XCTest
@testable import ExUno

final class ItalianNumbersTests: XCTestCase {
    func testIntegers() {
        let cases: [(Int, String)] = [
            (0, "zero"), (1, "uno"), (8, "otto"), (11, "undici"), (21, "ventuno"), (23, "ventitré"), (28, "ventotto"),
            (33, "trentatré"), (48, "quarantotto"), (100, "cento"), (101, "centouno"), (103, "centotré"), (108, "centotto"),
            (180, "centottanta"), (188, "centottantotto"), (200, "duecento"), (303, "trecentotré"), (1000, "mille"),
            (1001, "milleuno"), (2003, "duemilatré"), (2008, "duemilaotto"), (10_000, "diecimila"), (21_000, "ventunomila"),
            (23_000, "ventitremila"), (100_000, "centomila"), (123_456, "centoventitremilaquattrocentocinquantasei"),
            (1_000_000, "un milione"), (2_000_000, "due milioni"), (1_200_000, "un milione duecentomila"),
            (23_000_000, "ventitré milioni"), (1_000_000_000, "un miliardo"), (3_500_000_000, "tre miliardi cinquecento milioni")
        ]
        for (n, expected) in cases { XCTAssertEqual(ItalianNumbers.integer(n), expected, "\(n)") }
    }

    func testDecimalsAndParsing() throws {
        XCTAssertEqual(try ItalianNumbers.number("3,14"), "tre virgola quattordici")
        XCTAssertEqual(try ItalianNumbers.number("0,05"), "zero virgola zero cinque")
        XCTAssertEqual(try ItalianNumbers.number("-12.5"), "meno dodici virgola cinque")
        XCTAssertEqual(try ItalianNumbers.number("1.234"), "milleduecentotrentaquattro")
        XCTAssertEqual(try ItalianNumbers.number("1,234"), "uno virgola duecentotrentaquattro")
        XCTAssertEqual(try ItalianNumbers.number("1.234.567"), "un milione duecentotrentaquattromilacinquecentosessantasette")
        XCTAssertThrowsError(try ItalianNumbers.number("abc"))
        XCTAssertThrowsError(try ItalianNumbers.number("1,"))
    }

    func testOrdinals() throws {
        let cases: [(Int, String)] = [(1, "primo"), (2, "secondo"), (3, "terzo"), (10, "decimo"), (11, "undicesimo"), (12, "dodicesimo"),
                                      (20, "ventesimo"), (21, "ventunesimo"), (23, "ventitreesimo"), (26, "ventiseiesimo"), (28, "ventottesimo"),
                                      (100, "centesimo"), (103, "centotreesimo"), (110, "centodecimo"), (1000, "millesimo"), (2000, "duemillesimo"), (1001, "milleunesimo")]
        for (n, e) in cases { XCTAssertEqual(try ItalianNumbers.ordinal(n), e, "\(n)") }
        XCTAssertEqual(try ItalianNumbers.ordinal(1, ending: .feminine), "prima")
        XCTAssertEqual(try ItalianNumbers.ordinal(3, ending: .femininePlural), "terze")
    }

    func testPrices() throws {
        XCTAssertEqual(try ItalianNumbers.price("1").formal, "un euro")
        XCTAssertEqual(try ItalianNumbers.price("12,50").spoken, "dodici e cinquanta")
        XCTAssertEqual(try ItalianNumbers.price("12,50").formal, "dodici euro e cinquanta centesimi")
        XCTAssertEqual(try ItalianNumbers.price("0.50").formal, "cinquanta centesimi")
        XCTAssertEqual(try ItalianNumbers.price("1,01").formal, "un euro e un centesimo")
        XCTAssertEqual(try ItalianNumbers.price("3,05").spoken, "tre e cinque")
        XCTAssertEqual(try ItalianNumbers.price("12,50").display, "€ 12,50")
    }

    func testFloorsPercentTemperature() throws {
        XCTAssertEqual(ItalianNumbers.floor(0), "il piano terra")
        XCTAssertEqual(ItalianNumbers.floor(3), "il terzo piano")
        XCTAssertEqual(ItalianNumbers.floor(-1), "il piano interrato")
        XCTAssertEqual(try ItalianNumbers.percent("30").plain, "trenta per cento")
        XCTAssertEqual(try ItalianNumbers.temperature("-3").words, "meno tre gradi")
        XCTAssertEqual(try ItalianNumbers.temperature("1").words, "un grado")
    }
}

final class ItalianTimeTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(ItalianTime.everyday(hour: 1, minute: 0), "È l'una in punto")
        XCTAssertEqual(ItalianTime.everyday(hour: 7, minute: 45), "Sono le otto meno un quarto")
        XCTAssertEqual(ItalianTime.everyday(hour: 12, minute: 30), "È mezzogiorno e mezza")
        XCTAssertEqual(ItalianTime.everyday(hour: 0, minute: 10), "È mezzanotte e dieci")
        XCTAssertEqual(ItalianTime.everyday(hour: 18, minute: 50), "Sono le sette meno dieci")
        XCTAssertEqual(ItalianTime.everyday(hour: 14, minute: 20), "Sono le due e venti")
        let ex = ItalianTime.expressions(hour: 13, minute: 15)
        XCTAssertTrue(ex.contains { $0.text == "Sono le tredici e quindici" })
        XCTAssertTrue(ex.contains { $0.text == "Ci vediamo all'una e un quarto" })
        XCTAssertFalse(ItalianTime.expressions(hour: 0, minute: 10).contains { $0.text.contains("le zero") })
    }

    func testDates() {
        let cal = Calendar(identifier: .gregorian)
        let nov1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let w = ItalianTime.date(nov1, calendar: cal)
        XCTAssertEqual(w.full, "domenica primo novembre duemilaventisei")
        XCTAssertEqual(w.short, "il primo novembre")
        XCTAssertEqual(w.numeric, "01/11/2026")
        XCTAssertEqual(w.written, "1º novembre 2026")
        let mar8 = cal.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        XCTAssertEqual(ItalianTime.date(mar8, calendar: cal).short, "l'otto marzo")
    }

    func testYears() throws {
        let y = try ItalianTime.year(1485)
        XCTAssertEqual(y.words, "millequattrocentottantacinque")
        XCTAssertEqual(y.century, "XV secolo")
        XCTAssertEqual(y.centuryName, "il Quattrocento")
        XCTAssertEqual(try ItalianTime.year(1987).decade, "gli anni Ottanta")
        XCTAssertEqual(try ItalianTime.year(1500).century, "XV secolo")
        XCTAssertEqual(try ItalianTime.year(1500).centuryName, "il Cinquecento")
    }
}

final class ItalianEverydayTests: XCTestCase {
    func testPhone() throws {
        let p = try ItalianEveryday.phone("333 1234567")
        XCTAssertEqual(p.display, "333 12 34 56 7")
        XCTAssertEqual(p.grouped, "tre tre tre, dodici, trentaquattro, cinquantasei, sette")
        XCTAssertEqual(try ItalianEveryday.phone("06 12345678").grouped, "zero sei, dodici, trentaquattro, cinquantasei, settantotto")
    }

    func testMarket() throws {
        XCTAssertEqual(try ItalianEveryday.weight(grams: 100).first, "un etto")
        XCTAssertEqual(try ItalianEveryday.weight(grams: 250).first, "due etti e mezzo")
        XCTAssertEqual(try ItalianEveryday.weight(grams: 500).first, "mezzo chilo")
        XCTAssertEqual(try ItalianEveryday.weight(grams: 1500).first, "un chilo e mezzo")
        XCTAssertEqual(try ItalianEveryday.weight(grams: 1200).first, "un chilo e duecento grammi")
        XCTAssertEqual(try ItalianEveryday.volume(millilitres: 500).first, "mezzo litro")
        XCTAssertEqual(try ItalianEveryday.volume(millilitres: 250).first, "un quarto di litro")
    }
}

final class ConjugatorTests: XCTestCase {
    private func forms(_ verb: String, _ tense: String) -> [String] {
        Conjugator.conjugate(verb)?.tenses.first { $0.name == tense }?.forms ?? []
    }
    func testRegular() {
        XCTAssertEqual(forms("parlare", "Presente"), ["parlo", "parli", "parla", "parliamo", "parlate", "parlano"])
        XCTAssertEqual(forms("mangiare", "Presente"), ["mangio", "mangi", "mangia", "mangiamo", "mangiate", "mangiano"])
        XCTAssertEqual(forms("cercare", "Presente"), ["cerco", "cerchi", "cerca", "cerchiamo", "cercate", "cercano"])
        XCTAssertEqual(forms("finire", "Presente"), ["finisco", "finisci", "finisce", "finiamo", "finite", "finiscono"])
        XCTAssertEqual(forms("dormire", "Futuro semplice"), ["dormirò", "dormirai", "dormirà", "dormiremo", "dormirete", "dormiranno"])
        XCTAssertEqual(forms("mangiare", "Futuro semplice").first, "mangerò")
        XCTAssertEqual(forms("cercare", "Futuro semplice").first, "cercherò")
    }
    func testIrregular() {
        XCTAssertEqual(forms("essere", "Presente"), ["sono", "sei", "è", "siamo", "siete", "sono"])
        XCTAssertEqual(forms("andare", "Passato prossimo"), ["sono andato", "sei andato", "è andato/andata", "siamo andati", "siete andati", "sono andati"])
        XCTAssertEqual(forms("fare", "Imperfetto").first, "facevo")
        XCTAssertEqual(forms("bere", "Futuro semplice").first, "berrò")
        XCTAssertEqual(forms("prendere", "Passato prossimo").first, "ho preso")
    }
    func testReflexive() {
        XCTAssertEqual(forms("alzarsi", "Presente"), ["mi alzo", "ti alzi", "si alza", "ci alziamo", "vi alzate", "si alzano"])
        XCTAssertEqual(forms("alzarsi", "Passato prossimo").first, "mi sono alzato")
    }
    func testRejectsNonVerbs() {
        XCTAssertNil(Conjugator.conjugate("casa"))
        XCTAssertNil(Conjugator.conjugate(""))
    }
}
