import XCTest
@testable import ExUno

final class NumberInputSuffixTests: XCTestCase {
    func testEnglishOrdinalsAndTeenExceptions() {
        for (input, ending) in [("1", "st"), ("2", "nd"), ("3", "rd"), ("4", "th"),
                                ("11", "th"), ("12", "th"), ("13", "th"), ("21", "st"),
                                ("112", "th"), ("1234", "th"), ("1.001", "st")] {
            XCTAssertEqual(NumberInputSuffix.text(for: input, mode: "ordinal"), ending, input)
        }
        XCTAssertEqual(NumberInputSuffix.text(for: "XII", mode: "ordinal", romanInput: true), "th")
        XCTAssertNil(NumberInputSuffix.text(for: "", mode: "ordinal"))
        XCTAssertNil(NumberInputSuffix.text(for: "1,5", mode: "ordinal"))
    }
}
