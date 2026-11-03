import XCTest
@testable import ExUno

final class MotionFeedbackTests: XCTestCase {
    func testRelativeMotionDoesNotJumpAtAngleBoundary() {
        XCTAssertEqual(MotionFeedback.relativeAngle(-.pi + 0.02, .pi - 0.02), 0.04, accuracy: 0.000001)
        XCTAssertEqual(MotionFeedback.relativeAngle(.pi - 0.02, -.pi + 0.02), -0.04, accuracy: 0.000001)
    }
}
