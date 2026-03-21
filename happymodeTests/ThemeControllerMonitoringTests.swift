import Foundation
@testable import HappymodeCore
import XCTest

@MainActor
final class ThemeControllerMonitoringTests: XCTestCase {
    func testCachedCoordinateIsFreshWithinMaxAge() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let recentTimestamp = now.addingTimeInterval(-(23 * 60 * 60))

        XCTAssertTrue(ThemeController.cachedCoordinateIsFresh(timestamp: recentTimestamp, now: now))
    }

    func testCachedCoordinateExpiresAfterMaxAge() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let staleTimestamp = now.addingTimeInterval(-(25 * 60 * 60))

        XCTAssertFalse(ThemeController.cachedCoordinateIsFresh(timestamp: staleTimestamp, now: now))
    }

    func testCachedCoordinateRejectsFutureTimestamp() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let futureTimestamp = now.addingTimeInterval(60 * 60)

        XCTAssertFalse(ThemeController.cachedCoordinateIsFresh(timestamp: futureTimestamp, now: now))
    }
}
