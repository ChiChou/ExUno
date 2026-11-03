import XCTest
@testable import ExUno

final class CoachQuizTests: XCTestCase {
    func testRejectsUnanchoredOrMalformedQuestions() {
        func quiz(_ question: String, _ options: [String], _ answer: String) -> CoachQuiz {
            CoachQuiz(question: question, options: options, answer: answer, explanation: "")
        }
        XCTAssertTrue(quiz("Io ___ qui.", ["sono", "sei", "è"], "sono").hasValidStructure(expectedAnswer: "sono"))
        XCTAssertFalse(quiz("Io ___ qui.", ["sono", "sei", "è"], "sei").hasValidStructure(expectedAnswer: "sono"))
        XCTAssertFalse(quiz("Io ___ e ___ qui.", ["sono", "sei", "è"], "sono").hasValidStructure(expectedAnswer: "sono"))
        XCTAssertFalse(quiz("Io ___ qui.", ["sono", "sono", "è"], "sono").hasValidStructure(expectedAnswer: "sono"))
        XCTAssertFalse(quiz("Io ___ qui.", ["sei", "è", " "], "sono").hasValidStructure(expectedAnswer: "sono"))
    }
}
