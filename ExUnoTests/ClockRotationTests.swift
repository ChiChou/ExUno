import XCTest
@testable import ExUno

final class ClockRotationTests: XCTestCase {
    private let size = CGSize(width: 200, height: 200)

    private func point(_ degrees: Double) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: 100 + 90 * sin(angle), y: 100 - 90 * cos(angle))
    }

    func testStartingAnywhereDoesNotJumpAndAFullTurnAdvancesAnHour() {
        var dial = ClockRotation(hour: 10, minute: 20)
        let start = dial.move(to: point(90), in: size)
        XCTAssertEqual(start?.hour, 10)
        XCTAssertEqual(start?.minute, 20)
        for angle in [180.0, 270, 360] { _ = dial.move(to: point(angle), in: size) }
        let end = dial.move(to: point(90), in: size)
        XCTAssertEqual(end?.hour, 11)
        XCTAssertEqual(end?.minute, 20)
    }

    func testBackwardRotationCrossesMidnight() {
        var dial = ClockRotation(hour: 0, minute: 5)
        _ = dial.move(to: point(0), in: size)
        let time = dial.move(to: point(-90), in: size)
        XCTAssertEqual(time?.hour, 23)
        XCTAssertEqual(time?.minute, 50)
    }

    func testCrossingTwelveUsesTheShortArcAndCarriesTheHour() {
        var dial = ClockRotation(hour: 11, minute: 59)
        _ = dial.move(to: point(350), in: size)
        let time = dial.move(to: point(10), in: size)
        XCTAssertEqual(time?.hour, 12)
        XCTAssertEqual(time?.minute, 2)
    }

    func testSmallMovementsAccumulateRatherThanRoundingEachEvent() {
        var dial = ClockRotation(hour: 23, minute: 59)
        _ = dial.move(to: point(0), in: size)
        for angle in 1...5 { _ = dial.move(to: point(Double(angle)), in: size) }
        let time = dial.move(to: point(6), in: size)
        XCTAssertEqual(time?.hour, 0)
        XCTAssertEqual(time?.minute, 0)
    }

    func testCrossingThePivotDoesNotJump() {
        var dial = ClockRotation(hour: 8, minute: 0)
        _ = dial.move(to: point(90), in: size)
        XCTAssertNil(dial.move(to: CGPoint(x: 100, y: 100), in: size))
        let time = dial.move(to: point(270), in: size)
        XCTAssertEqual(time?.hour, 8)
        XCTAssertEqual(time?.minute, 0)
    }

    func testPointerAnimationUsesTheShortPathAcrossTwelve() {
        let current = 59.0 * .pi / 30
        let next = ClockRotation.nearestAngle(0, to: current)
        XCTAssertEqual(next - current, .pi / 30, accuracy: 0.000001)
        XCTAssertEqual(ClockRotation.nearestAngle(current, to: 0), -.pi / 30, accuracy: 0.000001)
    }
}
