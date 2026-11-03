import XCTest
@testable import ExUno

final class RecallTests: XCTestCase {
    private func fixture(count: Int = 8, realia: Bool = false) -> (Vocabulary, StudyProgress, DeckEngine) {
        let entries = (1...count).map { Entry(i: $0, w: "parola\($0)", t: "word", l: "A1", p: "noun", x: "", e: "", z: 1) }
        let file = LanguagePackFile(code: "it", schema: 2, levels: ["A1"], defaultLevels: ["A1"], topics: [], entries: entries, marketUnits: nil)
        let vocab = Vocabulary(pack: LoadedPack(code: .it, file: file))
        let progress = StudyProgress(inMemory: true)
        progress.settings.mode = .recall
        progress.settings.realia = realia
        let deck = DeckEngine()
        deck.build(vocab: vocab, progress: progress)
        return (vocab, progress, deck)
    }

    func testUndoRemovesNewReviewAndRestoresRevealedCard() {
        let (vocab, progress, deck) = fixture()
        let original = deck.queue.map(\.id)
        deck.revealed = true
        deck.advance(.good, vocab: vocab, progress: progress)
        XCTAssertEqual(progress.todayLog().reviews, 1)
        XCTAssertEqual(progress.pack.cards.count, 1)
        XCTAssertTrue(deck.undo(progress: progress))
        XCTAssertTrue(progress.pack.cards.isEmpty)
        XCTAssertNil(progress.pack.log[StudyProgress.today()])
        XCTAssertEqual(deck.queue.map(\.id), original)
        XCTAssertEqual(deck.index, 0)
        XCTAssertTrue(deck.revealed)
        XCTAssertFalse(deck.undo(progress: progress))
    }

    func testUndoRestoresExistingScheduleAndRemovesQueuedRepeat() {
        let (vocab, progress, deck) = fixture()
        guard case .word(let id, _) = deck.current else { return XCTFail("Expected word") }
        let old = CardState(due: 10, interval: 12, ease: 2.3, reps: 4, lapses: 1, lastSeen: 9, added: 1)
        progress.pack.cards[id] = old
        let before = deck.queue.map(\.id)
        deck.advance(.again, vocab: vocab, progress: progress)
        XCTAssertEqual(deck.queue.count, before.count + 1)
        XCTAssertEqual(progress.pack.cards[id]?.lapses, 2)
        XCTAssertTrue(deck.undo(progress: progress))
        XCTAssertEqual(progress.pack.cards[id], old)
        XCTAssertEqual(deck.queue.map(\.id), before)
    }

    func testUndoAlsoRollsBackRefillAndGoalSummary() {
        let (vocab, progress, deck) = fixture(count: 1)
        progress.app.goal = 1
        let before = deck.queue.map(\.id)
        deck.advance(.good, vocab: vocab, progress: progress)
        XCTAssertGreaterThan(deck.queue.count, before.count)
        XCTAssertTrue(deck.summaryDue)
        XCTAssertTrue(deck.undo(progress: progress))
        XCTAssertEqual(deck.queue.map(\.id), before)
        XCTAssertFalse(deck.summaryDue)
    }

    func testUndoRealiaRestoresLogAndRepeatQueue() {
        let (vocab, progress, deck) = fixture(realia: true)
        for _ in 0..<5 { deck.advance(.good, vocab: vocab, progress: progress) }
        guard case .realia = deck.current else { return XCTFail("Expected realia") }
        let oldLog = progress.todayLog(), oldQueue = deck.queue.map(\.id)
        deck.advance(.again, vocab: vocab, progress: progress)
        XCTAssertEqual(progress.todayLog().again, oldLog.again + 1)
        XCTAssertTrue(deck.undo(progress: progress))
        XCTAssertEqual(progress.todayLog(), oldLog)
        XCTAssertEqual(deck.queue.map(\.id), oldQueue)
    }

    func testUndoCannotOverwriteAConcurrentReview() {
        let (vocab, progress, deck) = fixture()
        deck.advance(.good, vocab: vocab, progress: progress)
        progress.grade(999, .good)
        XCTAssertFalse(deck.canUndo(progress: progress))
        XCTAssertFalse(deck.undo(progress: progress))
        XCTAssertEqual(progress.todayLog().reviews, 2)
    }

    func testRoamingNeverGradesOrOffersUndo() {
        let (vocab, progress, deck) = fixture()
        deck.buildRoaming(vocab: vocab, settings: progress.settings)
        deck.advance(.again, vocab: vocab, progress: progress)
        XCTAssertTrue(progress.pack.cards.isEmpty)
        XCTAssertTrue(progress.pack.log.isEmpty)
        XCTAssertFalse(deck.canUndo(progress: progress))
        XCTAssertTrue(deck.canGoBack)
    }

    func testUndoDeletionSurvivesStaleCloudCopyInEitherMergeOrder() throws {
        let (vocab, progress, deck) = fixture()
        deck.advance(.good, vocab: vocab, progress: progress)
        let stale = progress.pack
        XCTAssertTrue(deck.undo(progress: progress))
        // Round-trip ensures the deletion markers survive persistence too.
        let corrected = try JSONDecoder().decode(PackProgress.self, from: JSONEncoder().encode(progress.pack))
        for merged in [corrected.merged(with: stale), stale.merged(with: corrected)] {
            XCTAssertTrue(merged.cards.isEmpty)
            XCTAssertTrue(merged.log.isEmpty)
        }
    }

    func testLegacyProgressStillMergesAndDecodes() throws {
        var old = PackProgress()
        old.cards[1] = CardState(reps: 3)
        old.log[10] = DayLog(reviews: 3, good: 3)
        let decoded = try JSONDecoder().decode(PackProgress.self, from: JSONEncoder().encode(old))
        XCTAssertNil(decoded.reviewModified)
        var newer = PackProgress()
        newer.cards[1] = CardState(reps: 4)
        newer.log[10] = DayLog(reviews: 4, good: 4)
        XCTAssertEqual(decoded.merged(with: newer).cards[1]?.reps, 4)
        XCTAssertEqual(decoded.merged(with: newer).log[10]?.reviews, 4)
    }

    func testGesturesDistinguishFlickPullAndScroll() {
        func action(_ x: CGFloat, _ y: CGFloat, predictedX: CGFloat = 0) -> RecallSwipe? {
            RecallSwipe.action(translation: CGSize(width: x, height: y), predicted: CGSize(width: predictedX, height: y))
        }
        XCTAssertEqual(action(110, 10), .moveOn)
        XCTAssertEqual(action(-110, 10), .moveOn)
        XCTAssertEqual(action(40, 5, predictedX: 240), .moveOn)
        XCTAssertEqual(action(5, 110), .repeatSoon)
        XCTAssertNil(action(5, -150))
        XCTAssertNil(action(20, 15))
        XCTAssertNil(action(45, -100, predictedX: 240))
    }
}
