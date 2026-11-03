import XCTest
@testable import ExUno

final class ConversationTopicTests: XCTestCase {
    func testCatalogHasDistinctUsableTopicsAndAvoidsImmediateRepeat() {
        let topics = ConversationTopic.all
        XCTAssertGreaterThan(topics.count, 1)
        XCTAssertEqual(Set(topics.map(\.id)).count, topics.count)
        for topic in topics {
            XCTAssertFalse(topic.situation.isEmpty)
            XCTAssertFalse(topic.direction.isEmpty)
            XCTAssertFalse(topic.keywords.isEmpty)
            XCTAssertNotEqual(ConversationTopic.choose(excluding: topic.id).id, topic.id)
            for language in ["it", "es", "es-419", "fr", "pt", "pt-BR"].compactMap(LanguageCode.init(rawValue:)) {
                let lines = topic.lines(for: language)
                XCTAssertFalse(lines?.opening.isEmpty ?? true)
                XCTAssertFalse(lines?.example.isEmpty ?? true)
                XCTAssertFalse(lines?.followUp.isEmpty ?? true)
                XCTAssertFalse(lines?.secondExample.isEmpty ?? true)
                XCTAssertFalse(lines?.closing.isEmpty ?? true)
            }
            XCTAssertNil(topic.lines(for: .la))
        }
    }

    func testScriptMatchingAllowsCaseAccentsAndPunctuationButNotDifferentAnswers() {
        XCTAssertTrue(CoachView.matchesScript("un cafe por favor", "Un café, por favor."))
        XCTAssertFalse(CoachView.matchesScript("un té, por favor", "Un café, por favor."))
        XCTAssertFalse(CoachView.matchesScript("", ""))
    }
}
