import Foundation
@testable import HappymodeCore
import XCTest

final class MenuBarStatusFormatterTests: XCTestCase {
    func testNextCountdownUpdateDateIgnoresPastTransition() {
        let now = Date(timeIntervalSinceReferenceDate: 10)
        let pastTransition = Date(timeIntervalSinceReferenceDate: 5)
        let expected = Date(timeIntervalSinceReferenceDate: 60)

        let nextUpdate = MenuBarStatusFormatter.nextCountdownUpdateDate(now: now, nextTransitionDate: pastTransition)

        XCTAssertEqual(nextUpdate.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 0.0001)
    }

    func testNextCountdownUpdateDateUsesSoonerTransition() {
        let now = Date(timeIntervalSinceReferenceDate: 10)
        let soonTransition = Date(timeIntervalSinceReferenceDate: 20)
        let expected = soonTransition

        let nextUpdate = MenuBarStatusFormatter.nextCountdownUpdateDate(now: now, nextTransitionDate: soonTransition)

        XCTAssertEqual(nextUpdate.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 0.0001)
    }
}
