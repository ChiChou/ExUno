import XCTest
@testable import ExUno

final class MarketQuantityTests: XCTestCase {
    private func units(_ language: LanguageCode) throws -> [MarketUnit] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: language.rawValue, withExtension: "json", subdirectory: "Packs")
                                ?? Bundle.main.url(forResource: language.rawValue, withExtension: "json"))
        return try JSONDecoder().decode(LanguagePackFile.self, from: Data(contentsOf: url)).availableMarketUnits
    }

    func testLanguageSpecificChoices() throws {
        XCTAssertTrue(try units(.it).contains(.etto))
        XCTAssertFalse(try units(.es).contains(.etto))
        XCTAssertTrue(try units(.fr).contains(.decilitre))
        XCTAssertTrue(try units(.la).isEmpty)
        for language in [LanguageCode.it, .es, .fr] {
            XCTAssertTrue(Set(try units(language)).isSuperset(of: [.gram, .kilogram, .millilitre, .centilitre, .litre]))
        }
    }

    func testPackMetadataOwnsOrderAndIgnoresUnknownUnits() throws {
        let json = """
        {"code":"it","schema":2,"levels":[],"defaultLevels":[],"topics":[],"entries":[],
         "marketUnits":["l","kg","l","future-unit"]}
        """
        let file = try JSONDecoder().decode(LanguagePackFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.availableMarketUnits, [.litre, .kilogram])
        let legacy = """
        {"code":"it","schema":2,"levels":[],"defaultLevels":[],"topics":[],"entries":[]}
        """
        let old = try JSONDecoder().decode(LanguagePackFile.self, from: Data(legacy.utf8))
        XCTAssertEqual(old.availableMarketUnits, [.gram, .millilitre])
    }

    func testExactDecimalScalingAndUnitSwitches() throws {
        XCTAssertEqual(try MarketQuantity(text: "0,25", unit: .kilogram).baseValue, 250)
        XCTAssertEqual(try MarketQuantity(text: "1.234", unit: .kilogram).baseValue, 1234)
        XCTAssertEqual(try MarketQuantity(text: "0.001", unit: .litre).baseValue, 1)
        XCTAssertEqual(try MarketQuantity(text: "2,5", unit: .etto).baseValue, 250)
        XCTAssertEqual(try MarketQuantity(text: "75", unit: .centilitre).baseValue, 750)
        XCTAssertEqual(try MarketQuantity(text: "2", unit: .decilitre).baseValue, 200)
        XCTAssertEqual(MarketUnit.gram.converted("250", to: .kilogram), "0,25")
        XCTAssertEqual(MarketUnit.kilogram.converted("0,25", to: .etto), "2,5")
        XCTAssertEqual(MarketUnit.centilitre.converted("75", to: .litre), "0,75")
        XCTAssertEqual(MarketUnit.gram.converted("250", to: .litre), "0,5")
    }

    func testNativeUnitPhrases() throws {
        func run(_ language: LanguageCode, _ text: String, _ unit: MarketUnit) throws -> ToolOutput {
            var input = ToolInput()
            input.text = text
            input.unit = unit.rawValue
            return try language.engine.run(.market, input)
        }
        XCTAssertEqual(try run(.it, "2,5", .etto).headline, "Vorrei due etti e mezzo, per favore")
        XCTAssertEqual(try run(.it, "1", .etto).sub, "1 etto")
        XCTAssertEqual(try run(.it, "2", .centilitre).headline, "Vorrei due centilitri, per favore")
        XCTAssertEqual(try run(.fr, "0,5", .kilogram).headline, "Je voudrais un demi-kilo, s'il vous plaît")
        XCTAssertEqual(try run(.fr, "75", .centilitre).headline, "Je voudrais soixante-quinze centilitres, s'il vous plaît")
        XCTAssertEqual(try run(.fr, "2", .decilitre).headline, "Je voudrais deux décilitres, s'il vous plaît")
        XCTAssertEqual(try run(.es, "21", .centilitre).headline, "Póngame veintiún centilitros, por favor")
        XCTAssertEqual(try run(.es, "1,5", .litre).headline, "Póngame un litro y medio, por favor")
    }

    func testEveryOfferedPresetWorksInItsLanguageEngine() throws {
        for language in [LanguageCode.it, .es, .fr] {
            for unit in try units(language) {
                for preset in unit.presets {
                    var input = ToolInput()
                    input.text = preset
                    input.unit = unit.rawValue
                    let output = try language.engine.run(.market, input)
                    XCTAssertFalse(output.headline.isEmpty)
                    XCTAssertFalse(output.sub?.isEmpty ?? true)
                }
            }
        }
    }

    func testInvalidQuantitiesAreRejectedInsteadOfDroppingPunctuation() {
        for text in ["", "0", "-2", "1abc", "1,2,3", "1,", "100001", "0,5"] {
            XCTAssertThrowsError(try MarketQuantity(text: text, unit: .gram), text)
        }
        XCTAssertThrowsError(try MarketQuantity(text: "100,001", unit: .kilogram))
        var unsupported = ToolInput()
        unsupported.text = "2"
        unsupported.unit = "etto"
        XCTAssertThrowsError(try SpanishEngine().run(.market, unsupported))
    }
}
