import XCTest
@testable import ExUno

final class DailyChallengeProgressTests: XCTestCase {
    func testOldProgressStillDecodes() throws {
        let data = Data(#"{"day":123,"index":2,"correct":1,"done":false}"#.utf8)
        let state = try JSONDecoder().decode(Challenge.self, from: data)
        XCTAssertEqual(state.index, 2)
        XCTAssertEqual(state.correct, 1)
        XCTAssertNil(state.practice)
        XCTAssertNil(state.answerWasCorrect)
    }

    func testQuestionPlanAndPendingAnswerSurviveRelaunch() throws {
        var state = Challenge(day: 123)
        state.practice = [0: DailyChoiceQuestion(kind: .meaning, prompt: "cane", spoken: "il cane",
                                               options: ["dog", "cat", "bird"], answer: "dog", explanation: nil)]
        state.chosenAnswer = "dog"
        state.answerWasCorrect = true
        state.correct = 1
        let restored = try JSONDecoder().decode(Challenge.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
        XCTAssertEqual(restored.practice?[0]?.answer, "dog")
        XCTAssertEqual(restored.answerWasCorrect, true)
    }

    func testSyncKeepsAnAnsweredQuestionBeforeNextIsPressed() {
        var local = PackProgress()
        local.challenge = Challenge(day: 123)
        var remote = local
        remote.challenge.chosenAnswer = "dog"
        remote.challenge.answerWasCorrect = true
        remote.challenge.correct = 1
        XCTAssertEqual(local.merged(with: remote).challenge, remote.challenge)
        XCTAssertEqual(remote.merged(with: local).challenge, remote.challenge)
    }
}
