import XCTest
@testable import ExUno

final class CoachHistoryTests: XCTestCase {
    func testRoundTripAndLanguageIsolation() throws {
        let suite = "CoachHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = CoachHistory(defaults: defaults)
        let first = SavedCoachConversation(topicID: "cafe", messages: [CoachMessage(text: "Ciao", isUser: false), CoachMessage(text: "Salve", isUser: true)], scriptStep: nil, draft: "un caffè")
        history.save(first, language: .it)
        XCTAssertEqual(history.load(.it), first)
        XCTAssertNil(history.load(.es))
        let second = SavedCoachConversation(topicID: "market", messages: [CoachMessage(text: "Hola", isUser: false)], scriptStep: 0, draft: "")
        history.save(second, language: .es)
        XCTAssertEqual(history.load(.es), second)
        XCTAssertEqual(history.load(.it), first)
    }
}
