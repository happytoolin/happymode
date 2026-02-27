import Foundation
@testable import HappymodeCore
import XCTest

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
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
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
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
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
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
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
        case let .fixed(isDarkMode, message):
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
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, tomorrowSunrise)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleBeforeSunriseTransitionsToSunrise() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 5, minute: 30, calendar: calendar)
        let sunrise = makeDate(year: 2026, month: 2, day: 24, hour: 7, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .normal(
                sunrise: sunrise,
                sunset: makeDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0, calendar: calendar)
            ),
            tomorrow: .normal(
                sunrise: makeDate(year: 2026, month: 2, day: 25, hour: 7, minute: 1, calendar: calendar),
                sunset: makeDate(year: 2026, month: 2, day: 25, hour: 18, minute: 1, calendar: calendar)
            )
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, sunrise)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleAfterSunsetStaysDarkWhenTomorrowAlwaysDark() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 21, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .normal(
                sunrise: makeDate(year: 2026, month: 2, day: 24, hour: 7, minute: 0, calendar: calendar),
                sunset: makeDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0, calendar: calendar)
            ),
            tomorrow: .alwaysDark,
            calendar: calendar
        )

        switch decision {
        case let .fixed(isDarkMode, message):
            XCTAssertTrue(isDarkMode)
            XCTAssertEqual(message, "Polar night: staying in Dark mode.")
        default:
            XCTFail("Expected fixed decision")
        }
    }

    func testSolarScheduleAfterSunsetBeforeAlwaysLightTomorrowTransitionsAtMidnight() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 22, minute: 0, calendar: calendar)
        let midnight = makeDate(year: 2026, month: 2, day: 25, hour: 0, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .normal(
                sunrise: makeDate(year: 2026, month: 2, day: 24, hour: 6, minute: 0, calendar: calendar),
                sunset: makeDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0, calendar: calendar)
            ),
            tomorrow: .alwaysLight,
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, midnight)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleAlwaysDarkTodayTransitionsAtMidnightForTomorrowAlwaysLight() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 12, day: 20, hour: 13, minute: 0, calendar: calendar)
        let midnight = makeDate(year: 2026, month: 12, day: 21, hour: 0, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysDark,
            tomorrow: .alwaysLight,
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, midnight)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleAlwaysDarkTodayStaysDarkWhenTomorrowAlwaysDark() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 12, day: 20, hour: 13, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysDark,
            tomorrow: .alwaysDark
        )

        switch decision {
        case let .fixed(isDarkMode, message):
            XCTAssertTrue(isDarkMode)
            XCTAssertEqual(message, "Polar night: staying in Dark mode.")
        default:
            XCTFail("Expected fixed decision")
        }
    }

    func testSolarScheduleAlwaysDarkTodayTransitionsToTomorrowSunriseWhenAvailable() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 12, day: 1, hour: 12, minute: 0, calendar: calendar)
        let tomorrowSunrise = makeDate(year: 2026, month: 12, day: 2, hour: 9, minute: 30, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysDark,
            tomorrow: .normal(
                sunrise: tomorrowSunrise,
                sunset: makeDate(year: 2026, month: 12, day: 2, hour: 15, minute: 0, calendar: calendar)
            ),
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, tomorrowSunrise)
            XCTAssertFalse(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleAlwaysLightTodayTransitionsToTomorrowSunsetWhenAvailable() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 6, day: 20, hour: 12, minute: 0, calendar: calendar)
        let tomorrowSunset = makeDate(year: 2026, month: 6, day: 21, hour: 22, minute: 10, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysLight,
            tomorrow: .normal(
                sunrise: makeDate(year: 2026, month: 6, day: 21, hour: 3, minute: 45, calendar: calendar),
                sunset: tomorrowSunset
            )
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertFalse(currentIsDarkMode)
            XCTAssertEqual(nextTransition, tomorrowSunset)
            XCTAssertTrue(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testSolarScheduleAlwaysLightTodayStaysLightWhenTomorrowAlwaysLight() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 6, day: 20, hour: 12, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysLight,
            tomorrow: .alwaysLight
        )

        switch decision {
        case let .fixed(isDarkMode, message):
            XCTAssertFalse(isDarkMode)
            XCTAssertEqual(message, "Midnight sun: staying in Light mode.")
        default:
            XCTFail("Expected fixed decision")
        }
    }

    func testSolarScheduleAlwaysLightTodayTransitionsAtMidnightForTomorrowAlwaysDark() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 6, day: 30, hour: 12, minute: 0, calendar: calendar)
        let midnight = makeDate(year: 2026, month: 7, day: 1, hour: 0, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: .alwaysLight,
            tomorrow: .alwaysDark,
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertFalse(currentIsDarkMode)
            XCTAssertEqual(nextTransition, midnight)
            XCTAssertTrue(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testCustomScheduleRejectsMissingComponents() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 12, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 8),
            darkTime: DateComponents(hour: 20, minute: 0),
            calendar: calendar
        )

        switch decision {
        case let .fixed(isDarkMode, message):
            XCTAssertFalse(isDarkMode)
            XCTAssertEqual(message, "Custom schedule is invalid.")
        default:
            XCTFail("Expected fixed decision")
        }
    }

    func testCustomScheduleAtExactLightTransitionUsesLightAsCurrentMode() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 7, minute: 0, calendar: calendar)
        let darkTransition = makeDate(year: 2026, month: 2, day: 24, hour: 19, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 7, minute: 0),
            darkTime: DateComponents(hour: 19, minute: 0),
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertFalse(currentIsDarkMode)
            XCTAssertEqual(nextTransition, darkTransition)
            XCTAssertTrue(nextIsDarkMode)
        default:
            XCTFail("Expected transition decision")
        }
    }

    func testCustomScheduleAtExactDarkTransitionUsesDarkAsCurrentMode() {
        let calendar = utcCalendar
        let now = makeDate(year: 2026, month: 2, day: 24, hour: 19, minute: 0, calendar: calendar)
        let nextLightTransition = makeDate(year: 2026, month: 2, day: 25, hour: 7, minute: 0, calendar: calendar)

        let decision = AppearanceScheduleEngine.evaluateCustom(
            now: now,
            lightTime: DateComponents(hour: 7, minute: 0),
            darkTime: DateComponents(hour: 19, minute: 0),
            calendar: calendar
        )

        switch decision {
        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            XCTAssertTrue(currentIsDarkMode)
            XCTAssertEqual(nextTransition, nextLightTransition)
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
