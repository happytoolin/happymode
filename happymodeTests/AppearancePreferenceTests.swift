import Foundation
@testable import HappymodeCore
import XCTest

final class AppearancePreferenceTests: XCTestCase {
    func testShortcutCycleMovesFromAutomaticToForceLight() {
        XCTAssertEqual(AppearancePreference.automatic.nextShortcutCycleValue, .forceLight)
    }

    func testShortcutCycleMovesFromForceLightToForceDark() {
        XCTAssertEqual(AppearancePreference.forceLight.nextShortcutCycleValue, .forceDark)
    }

    func testShortcutCycleWrapsFromForceDarkToAutomatic() {
        XCTAssertEqual(AppearancePreference.forceDark.nextShortcutCycleValue, .automatic)
    }
}
