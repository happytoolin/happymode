import Foundation
import XCTest
@testable import HappymodeCore

final class AppearanceScheduleEngineTests: XCTestCase {
    func testCustomScheduleBeforeLightTransition() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 6, minute: 0, calendar: calendar)
        let lightTransition = makeDate(year: 2026, month: 2, day: 24, hour: 7, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 7, minute: 0),
            darkTime: DateComponents(hour: 19, minute: 0),
            calendar: calendar
        )

        switch decision {
        case .transition(let currentIsDarkMode, let nextTransition, let nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, lightTransition)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testCustomScheduleAfterLightTransitionBeforeDarkTransition() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 12, minute: 0, calendar: calendar)
        let darkTransition = makeDate(year: 2026, month: 2, day: 24, hour: 19, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 7, minute: 0),
            darkTime: DateComponents(hour: 19, minute: 0),
            calendar: calendar
        )

        switch decision {
        case .transition(let currentIsDarkMode, let nextTransition, let nextIsDarkMode):
            XCTAssertFalse(currentIsDarkMode)
            XCTAssertEqual(nextTransition, darkTransition)
            XCTAssertTrue(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testCustomScheduleHandlesOvernightWindows() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 22, minute: 0, calendar: calendar)
        let nextDarkTransition = makeDate(year: 2026, month: 2, day: 25, hour: 6, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 20, minute: 0),
            darkTime: DateComponents(hour: 6, minute: 0),
            calendar: calendar
        )

        switch decision {
        case .transition(let currentIsDarkMode, let nextTransition, let nextIsDarkMode):
            XCTAssertFalse(currentIsDarkMode)
            XCTAssertEqual(nextTransition, nextDarkTransition)
            XCTAssertTrue(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testCustomScheduleRejectsIdenticalTimes() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 12, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 8, minute: 30),
            darkTime: DateComponents(hour: 8, minute: 30),
            calendar: calendar
        )

        switch decision {
        case .fixed(let isDarkMode, let message):
            XCTAssertFalse(isDarkMode)
            XCTAssertEqual(message, "Custom Light and Dark times cannot be identical.")
        default:
            XCTFail("Expected fixed decision")
        }
    }

    func testSolarScheduleAfterSunsetUsesTomorrowSunrise() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 20, minute: 0, calendar: calendar)
        let tomorrowSunrise = makeDate(year: 2026, month: 2, day: 25, hour: 7, minute: 10, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .normal(
                sunrise: makeDate(year: 2026, month: 2, day: 24, hour: 7, minute: 0, calendar: calendar),
                sunset: makeDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0, calendar: calendar)
            ),
            tomorrow: .normal(
                sunrise: tomorrowSunrise,
                sunset: makeDate(year: 2026, month: 2, day: 25, hour: 18, minute: 1, calendar: calendar)
            )
        )

        switch decision {
        case .transition(let currentIsDarkMode, let nextTransition, let nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, tomorrowSunrise)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(year: Int,
                          month: Int,
                          day: Int,
                          hour: Int,
                          minute: Int,
                          calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? .distantPast
    }
}
