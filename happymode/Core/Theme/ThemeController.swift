import AppKit
import Combine
import CoreLocation
import Foundation

enum AppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case forceLight
    case forceDark

    static let menuOrder: [AppearancePreference] = [.forceDark, .automatic, .forceLight]

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .forceLight:
            return "Light"
        case .forceDark:
            return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic:
            return "circle.lefthalf.filled"
        case .forceLight:
            return "sun.max.fill"
        case .forceDark:
            return "moon.fill"
        }
    }
}

enum AutomaticScheduleMode: String, CaseIterable, Identifiable {
    case sunriseSunset
    case customTimes

    static let menuOrder: [AutomaticScheduleMode] = [.sunriseSunset, .customTimes]

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .sunriseSunset:
            return "Sunrise/Sunset"
        case .customTimes:
            return "Custom Times"
        }
    }

    var systemImage: String {
        switch self {
        case .sunriseSunset:
            return "sun.horizon"
        case .customTimes:
            return "clock.badge"
        }
    }
}

enum AutomaticAppearanceDecision: Equatable {
    case transition(currentIsDarkMode: Bool, nextTransition: Date, nextIsDarkMode: Bool)
    case fixed(isDarkMode: Bool, message: String)
}

enum AppearanceScheduleEngine {
    static func evaluateSolar(now: Date,
                              today: SolarDayType,
                              tomorrow: SolarDayType,
                              calendar: Calendar = .current) -> AutomaticAppearanceDecision {
        switch today {
        case .alwaysDark:
            return evaluateAlwaysDark(now: now, tomorrow: tomorrow, calendar: calendar)
        case .alwaysLight:
            return evaluateAlwaysLight(now: now, tomorrow: tomorrow, calendar: calendar)
        case let .normal(sunrise, sunset):
            return evaluateNormal(now: now, sunrise: sunrise, sunset: sunset, tomorrow: tomorrow, calendar: calendar)
        }
    }

    private static func safeStartOfTomorrow(from now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return now.addingTimeInterval(60)
        }

        if startOfTomorrow <= now {
            return now.addingTimeInterval(60)
        }

        return startOfTomorrow
    }

    private static func futureTransition(_ candidate: Date, now: Date, calendar: Calendar) -> Date {
        candidate > now ? candidate : safeStartOfTomorrow(from: now, calendar: calendar)
    }

    private static func evaluateAlwaysDark(now: Date,
                                           tomorrow: SolarDayType,
                                           calendar: Calendar) -> AutomaticAppearanceDecision {
        switch tomorrow {
        case let .normal(nextSunrise, _):
            return .transition(
                currentIsDarkMode: true,
                nextTransition: futureTransition(nextSunrise, now: now, calendar: calendar),
                nextIsDarkMode: false
            )
        case .alwaysDark:
            return .fixed(isDarkMode: true, message: "Polar night: staying in Dark mode.")
        case .alwaysLight:
            return .transition(
                currentIsDarkMode: true,
                nextTransition: safeStartOfTomorrow(from: now, calendar: calendar),
                nextIsDarkMode: false
            )
        }
    }

    private static func evaluateAlwaysLight(now: Date,
                                            tomorrow: SolarDayType,
                                            calendar: Calendar) -> AutomaticAppearanceDecision {
        switch tomorrow {
        case let .normal(_, nextSunset):
            return .transition(
                currentIsDarkMode: false,
                nextTransition: futureTransition(nextSunset, now: now, calendar: calendar),
                nextIsDarkMode: true
            )
        case .alwaysDark:
            return .transition(
                currentIsDarkMode: false,
                nextTransition: safeStartOfTomorrow(from: now, calendar: calendar),
                nextIsDarkMode: true
            )
        case .alwaysLight:
            return .fixed(isDarkMode: false, message: "Midnight sun: staying in Light mode.")
        }
    }

    private static func evaluateNormal(now: Date,
                                       sunrise: Date,
                                       sunset: Date,
                                       tomorrow: SolarDayType,
                                       calendar: Calendar) -> AutomaticAppearanceDecision {
        if sunrise >= sunset {
            return evaluateAlwaysDark(now: now, tomorrow: tomorrow, calendar: calendar)
        }

        if now < sunrise {
            return .transition(
                currentIsDarkMode: true,
                nextTransition: futureTransition(sunrise, now: now, calendar: calendar),
                nextIsDarkMode: false
            )
        }

        if now < sunset {
            return .transition(
                currentIsDarkMode: false,
                nextTransition: futureTransition(sunset, now: now, calendar: calendar),
                nextIsDarkMode: true
            )
        }

        return evaluateAlwaysDark(now: now, tomorrow: tomorrow, calendar: calendar)
    }

    static func evaluateCustom(now: Date,
                               lightTime: DateComponents,
                               darkTime: DateComponents,
                               calendar: Calendar = .current) -> AutomaticAppearanceDecision {
        guard let lightHour = lightTime.hour,
              let lightMinute = lightTime.minute,
              let darkHour = darkTime.hour,
              let darkMinute = darkTime.minute
        else {
            return .fixed(isDarkMode: false, message: "Custom schedule is invalid.")
        }

        if lightHour == darkHour && lightMinute == darkMinute {
            return .fixed(isDarkMode: false, message: "Custom Light and Dark times cannot be identical.")
        }

        let startOfToday = calendar.startOfDay(for: now)
        let eventOffsets = [-1, 0, 1]
        var events: [CustomTransitionEvent] = []

        for offset in eventOffsets {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }

            if let lightDate = eventDate(on: day, time: lightTime, calendar: calendar) {
                events.append(CustomTransitionEvent(date: lightDate, darkMode: false, precedence: 0))
            }

            if let darkDate = eventDate(on: day, time: darkTime, calendar: calendar) {
                events.append(CustomTransitionEvent(date: darkDate, darkMode: true, precedence: 1))
            }
        }

        guard let latestPastEvent = events
            .filter({ $0.date <= now })
            .max(by: { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.precedence < rhs.precedence
                }
                return lhs.date < rhs.date
            }),
            let nextEvent = events
            .filter({ $0.date > now })
            .min(by: { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.precedence < rhs.precedence
                }
                return lhs.date < rhs.date
            })
        else {
            return .fixed(isDarkMode: false, message: "Custom schedule is invalid.")
        }

        return .transition(
            currentIsDarkMode: latestPastEvent.darkMode,
            nextTransition: nextEvent.date,
            nextIsDarkMode: nextEvent.darkMode
        )
    }

    private struct CustomTransitionEvent {
        let date: Date
        let darkMode: Bool
        let precedence: Int
    }

    private static func eventDate(on day: Date,
                                  time: DateComponents,
                                  calendar: Calendar) -> Date? {
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        dayComponents.hour = time.hour
        dayComponents.minute = time.minute
        dayComponents.second = 0
        return calendar.date(from: dayComponents)
    }
}

enum MenuBarStatusFormatter {
    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    static func remainingTime(until date: Date, now: Date) -> String {
        let interval = max(60, ceil(date.timeIntervalSince(now) / 60) * 60)
        return formatter.string(from: interval) ?? "0 min"
    }

    static func nextCountdownUpdateDate(now: Date, nextTransitionDate: Date) -> Date {
        let remainder = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
        let secondsToNextMinute = remainder == 0 ? 60 : 60 - remainder
        let minuteTickDate = now.addingTimeInterval(secondsToNextMinute)
        return nextTransitionDate > now ? min(nextTransitionDate, minuteTickDate) : minuteTickDate
    }
}

enum WeeklySolarKind {
    case normal(sunrise: Date, sunset: Date)
    case alwaysDark
    case alwaysLight
}

struct WeeklySolarDay: Identifiable {
    let date: Date
    let kind: WeeklySolarKind

    var id: Date {
        date
    }
}

@MainActor
final class ThemeController: NSObject, ObservableObject {
    @Published var useAutomaticLocation: Bool {
        didSet {
            defaults.set(useAutomaticLocation, forKey: Self.automaticLocationKey)
            if useAutomaticLocation && requiresLocationForActiveSchedule {
                requestLocationIfPossible(force: true)
            }
            refreshNow(forceLocation: false)
        }
    }

    @Published var appearancePreference: AppearancePreference {
        didSet {
            defaults.set(appearancePreference.rawValue, forKey: Self.appearancePreferenceKey)
            refreshNow(forceLocation: false)
        }
    }

    @Published var automaticScheduleMode: AutomaticScheduleMode {
        didSet {
            defaults.set(automaticScheduleMode.rawValue, forKey: Self.automaticScheduleModeKey)
            refreshNow(forceLocation: true)
        }
    }

    @Published var customLightTime: Date {
        didSet {
            defaults.set(Self.minutesSinceMidnight(for: customLightTime), forKey: Self.customLightMinutesKey)
            refreshNow(forceLocation: false)
        }
    }

    @Published var customDarkTime: Date {
        didSet {
            defaults.set(Self.minutesSinceMidnight(for: customDarkTime), forKey: Self.customDarkMinutesKey)
            refreshNow(forceLocation: false)
        }
    }

    @Published var showRemainingTimeInMenuBar: Bool {
        didSet {
            defaults.set(showRemainingTimeInMenuBar, forKey: Self.showRemainingTimeInMenuBarKey)
            let now = Date()
            updateMenuBarCountdownText(now: now)
            scheduleMenuBarCountdownUpdate(now: now)
        }
    }

    @Published var manualLatitude: Double? {
        didSet {
            if let manualLatitude {
                defaults.set(manualLatitude, forKey: Self.manualLatitudeKey)
            } else {
                defaults.removeObject(forKey: Self.manualLatitudeKey)
            }
            if !isBatchUpdatingManualCoordinates {
                refreshNow(forceLocation: false)
            }
        }
    }

    @Published var manualLongitude: Double? {
        didSet {
            if let manualLongitude {
                defaults.set(manualLongitude, forKey: Self.manualLongitudeKey)
            } else {
                defaults.removeObject(forKey: Self.manualLongitudeKey)
            }
            if !isBatchUpdatingManualCoordinates {
                refreshNow(forceLocation: false)
            }
        }
    }

    @Published private(set) var targetIsDarkMode: Bool
    @Published private(set) var nextTransitionText: String = "Calculating schedule..."
    @Published private(set) var nextTransitionDate: Date?
    @Published private(set) var menuBarCountdownText: String = ""
    @Published private(set) var locationStatusText: String = "Detecting location..."
    @Published private(set) var currentSunriseText: String = "--"
    @Published private(set) var currentSunsetText: String = "--"
    @Published private(set) var weeklySolarDays: [WeeklySolarDay] = []
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var automationPermissionKnown = false
    @Published private(set) var automationPermissionGranted = false
    @Published private(set) var errorText: String?

    var manualCoordinatesAreValid: Bool {
        manualCoordinates != nil
    }

    var hasManualCoordinateInput: Bool {
        manualLatitude != nil || manualLongitude != nil
    }

    var hasDetectedCoordinate: Bool {
        latestCoordinate != nil
    }

    var detectedCoordinateText: String? {
        guard let coordinate = latestCoordinate else {
            return nil
        }

        return "\(formatCoordinate(coordinate.latitude)), \(formatCoordinate(coordinate.longitude))"
    }

    var appearanceDescriptionText: String {
        switch appearancePreference {
        case .automatic:
            switch automaticScheduleMode {
            case .sunriseSunset:
                return "Automatic uses sunrise and sunset times."
            case .customTimes:
                return "Automatic uses your custom Light/Dark schedule."
            }
        case .forceLight:
            return "Forced Light mode ignores sunrise/sunset until switched back to Auto."
        case .forceDark:
            return "Forced Dark mode ignores sunrise/sunset until switched back to Auto."
        }
    }

    var shouldShowMenuBarCountdown: Bool {
        showRemainingTimeInMenuBar &&
            appearancePreference == .automatic &&
            nextTransitionDate != nil
    }

    var isLocationAuthorized: Bool {
        locationAuthorizationStatus == .authorized || locationAuthorizationStatus == .authorizedAlways
    }

    var locationSetupComplete: Bool {
        if !requiresLocationForActiveSchedule {
            return true
        }

        if useAutomaticLocation {
            return isLocationAuthorized
        }

        return manualCoordinates != nil
    }

    var automationSetupComplete: Bool {
        automationPermissionKnown && automationPermissionGranted
    }

    var setupNeeded: Bool {
        !locationSetupComplete || !automationSetupComplete
    }

    var setupStatusText: String {
        let missing = missingSetupLabels
        if missing.isEmpty {
            return "Setup complete"
        }

        return "Setup needed: \(missing.joined(separator: " + "))"
    }

    var setupGuidanceText: String {
        var guidance: [String] = []

        if !locationSetupComplete {
            if useAutomaticLocation {
                guidance.append("grant Location access")
            } else {
                guidance.append("enter manual coordinates")
            }
        }

        if !automationSetupComplete {
            guidance.append("grant Automation access")
        }

        if guidance.isEmpty {
            return "All required permissions are set."
        }

        return "Please \(guidance.joined(separator: " and "))."
    }

    var locationPermissionText: String {
        if !requiresLocationForActiveSchedule {
            return "Location not required for current mode"
        }

        if !useAutomaticLocation {
            return manualCoordinates != nil
                ? "Manual coordinates configured"
                : "Manual coordinates required while current location is off"
        }

        switch locationAuthorizationStatus {
        case .authorized, .authorizedAlways:
            return "Location access granted"
        case .notDetermined:
            return "Location permission not requested yet"
        case .denied:
            return "Location access denied"
        case .restricted:
            return "Location access restricted"
        @unknown default:
            return "Location permission unknown"
        }
    }

    var automationPermissionText: String {
        if !automationPermissionKnown {
            return "Automation permission not checked yet"
        }

        return automationPermissionGranted
            ? "Automation access granted"
            : "Automation access missing"
    }

    private static let automaticLocationKey = "useAutomaticLocation"
    private static let appearancePreferenceKey = "appearancePreference"
    private static let automaticScheduleModeKey = "automaticScheduleMode"
    private static let manualLatitudeKey = "manualLatitude"
    private static let manualLongitudeKey = "manualLongitude"
    private static let customLightMinutesKey = "customLightMinutes"
    private static let customDarkMinutesKey = "customDarkMinutes"
    private static let showRemainingTimeInMenuBarKey = "showRemainingTimeInMenuBar"
    private static let cachedLatitudeKey = "cachedDetectedLatitude"
    private static let cachedLongitudeKey = "cachedDetectedLongitude"

    private static let defaultCustomLightMinutes = 7 * 60
    private static let defaultCustomDarkMinutes = 19 * 60

    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private var latestCoordinate: CLLocationCoordinate2D?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var menuBarCountdownTask: Task<Void, Never>?
    private var lastLocationRequestDate: Date?
    private var isBatchUpdatingManualCoordinates = false
    private var staleTransitionRetryCount = 0

    private var missingSetupLabels: [String] {
        var missing: [String] = []

        if !locationSetupComplete {
            missing.append(useAutomaticLocation ? "Location Access" : "Manual Coordinates")
        }

        if !automationSetupComplete {
            missing.append("Automation Access")
        }

        return missing
    }

    var transitionStartTitle: String {
        automaticScheduleMode == .sunriseSunset ? "Sunrise" : "Light"
    }

    var transitionEndTitle: String {
        automaticScheduleMode == .sunriseSunset ? "Sunset" : "Dark"
    }

    var transitionStartSymbol: String {
        automaticScheduleMode == .sunriseSunset ? "sunrise.fill" : "sun.max.fill"
    }

    var transitionEndSymbol: String {
        automaticScheduleMode == .sunriseSunset ? "sunset.fill" : "moon.fill"
    }

    private var requiresLocationForActiveSchedule: Bool {
        appearancePreference == .automatic && automaticScheduleMode == .sunriseSunset
    }

    override init() {
        let storedAutomatic = defaults.object(forKey: Self.automaticLocationKey) as? Bool ?? true
        let storedPreference = AppearancePreference(rawValue: defaults.string(forKey: Self.appearancePreferenceKey) ?? "") ?? .automatic
        let storedScheduleMode = AutomaticScheduleMode(rawValue: defaults.string(forKey: Self.automaticScheduleModeKey) ?? "") ?? .sunriseSunset
        let storedLatitude = Self.storedCoordinateValue(defaults: defaults, key: Self.manualLatitudeKey)
        let storedLongitude = Self.storedCoordinateValue(defaults: defaults, key: Self.manualLongitudeKey)
        let storedLightMinutes = defaults.object(forKey: Self.customLightMinutesKey) as? Int ?? Self.defaultCustomLightMinutes
        let storedDarkMinutes = defaults.object(forKey: Self.customDarkMinutesKey) as? Int ?? Self.defaultCustomDarkMinutes
        let storedShowRemainingTime = defaults.object(forKey: Self.showRemainingTimeInMenuBarKey) as? Bool ?? true

        useAutomaticLocation = storedAutomatic
        appearancePreference = storedPreference
        automaticScheduleMode = storedScheduleMode
        customLightTime = Self.dateFromMinutesSinceMidnight(storedLightMinutes)
        customDarkTime = Self.dateFromMinutesSinceMidnight(storedDarkMinutes)
        showRemainingTimeInMenuBar = storedShowRemainingTime
        manualLatitude = storedLatitude
        manualLongitude = storedLongitude
        targetIsDarkMode = Self.systemIsCurrentlyDarkMode()
        locationAuthorizationStatus = locationManager.authorizationStatus

        if let cachedLat = defaults.object(forKey: Self.cachedLatitudeKey) as? Double,
           let cachedLon = defaults.object(forKey: Self.cachedLongitudeKey) as? Double,
           (-90 ... 90).contains(cachedLat),
           (-180 ... 180).contains(cachedLon) {
            latestCoordinate = CLLocationCoordinate2D(latitude: cachedLat, longitude: cachedLon)
        }

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        probeAndUpdateAutomationPermission()
        refreshNow(forceLocation: true)
    }

    deinit {
        scheduledRefreshTask?.cancel()
        menuBarCountdownTask?.cancel()
    }

    @objc private func calendarDayChanged() {
        refreshNow(forceLocation: true)
    }

    @objc private func appDidBecomeActive() {
        probeAndUpdateAutomationPermission()
        refreshNow(forceLocation: false)
    }

    private func probeAndUpdateAutomationPermission() {
        let granted = Self.probeAutomationPermission()
        automationPermissionKnown = true
        automationPermissionGranted = granted
        if granted { errorText = nil }
    }

    func requestLocationPermission() {
        locationAuthorizationStatus = locationManager.authorizationStatus

        if locationAuthorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }

        if isLocationAuthorized {
            locationManager.requestLocation()
        }
    }

    func requestAutomationPermission() {
        probeAndUpdateAutomationPermission()

        if !automationPermissionGranted {
            errorText = "Automation access not granted yet. Click Open Privacy and allow happymode under Automation."
        }

        refreshNow(forceLocation: false)
    }

    func openLocationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAutomationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    func fillManualCoordinatesFromDetected() {
        guard let coordinate = latestCoordinate else {
            return
        }

        isBatchUpdatingManualCoordinates = true
        manualLatitude = coordinate.latitude
        manualLongitude = coordinate.longitude
        isBatchUpdatingManualCoordinates = false
        refreshNow(forceLocation: false)
    }

    func refreshNow(forceLocation: Bool) {
        locationAuthorizationStatus = locationManager.authorizationStatus
        let now = Date()

        if useAutomaticLocation, requiresLocationForActiveSchedule {
            requestLocationIfPossible(force: forceLocation)
        }

        let coordinate = resolvedCoordinate()

        if automaticScheduleMode == .sunriseSunset {
            if let coordinate {
                if latestCoordinate != nil, useAutomaticLocation {
                    locationStatusText = "Using detected location"
                } else {
                    locationStatusText = "Using manual coordinates"
                }
                updateWeeklyForecast(for: coordinate, from: now)
            } else {
                locationStatusText = useAutomaticLocation
                    ? "Allow location access or enter manual coordinates."
                    : "Enter manual coordinates."
                currentSunriseText = "--"
                currentSunsetText = "--"
                weeklySolarDays = []
            }
        } else {
            currentSunriseText = formatTime(customLightTime)
            currentSunsetText = formatTime(customDarkTime)
            weeklySolarDays = []
            locationStatusText = "Custom schedule active (location optional)."
        }

        evaluateAndApply(for: coordinate, at: now)
        updateMenuBarCountdownText(now: now)
        scheduleMenuBarCountdownUpdate(now: now)
        scheduleNextRefresh(now: now)
    }

    private func requestLocationIfPossible(force: Bool) {
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorized, .authorizedAlways:
            if force || shouldRefreshLocation {
                locationManager.requestLocation()
                lastLocationRequestDate = Date()
            }

        case .denied, .restricted:
            if manualCoordinates != nil {
                locationStatusText = "Location access denied. Using manual coordinates."
            } else {
                locationStatusText = "Location access denied. Add manual coordinates."
            }

        @unknown default:
            break
        }
    }

    private var shouldRefreshLocation: Bool {
        guard let lastRequest = lastLocationRequestDate else {
            return true
        }

        return Date().timeIntervalSince(lastRequest) > 60 * 30
    }

    private func resolvedCoordinate() -> CLLocationCoordinate2D? {
        if useAutomaticLocation, let detected = latestCoordinate {
            return detected
        }
        return manualCoordinates
    }

    private var manualCoordinates: CLLocationCoordinate2D? {
        guard let latitude = manualLatitude,
              let longitude = manualLongitude,
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func updateWeeklyForecast(for coordinate: CLLocationCoordinate2D, from date: Date) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)

        var days: [WeeklySolarDay] = []

        for offset in 0 ..< 7 {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }

            switch SolarCalculator.solarDay(for: dayDate, coordinate: coordinate) {
            case let .normal(sunrise, sunset):
                days.append(WeeklySolarDay(date: dayDate, kind: .normal(sunrise: sunrise, sunset: sunset)))
            case .alwaysDark:
                days.append(WeeklySolarDay(date: dayDate, kind: .alwaysDark))
            case .alwaysLight:
                days.append(WeeklySolarDay(date: dayDate, kind: .alwaysLight))
            }
        }

        weeklySolarDays = days

        if let today = days.first {
            switch today.kind {
            case let .normal(sunrise, sunset):
                currentSunriseText = formatTime(sunrise)
                currentSunsetText = formatTime(sunset)

            case .alwaysDark:
                currentSunriseText = "No sunrise"
                currentSunsetText = "No sunset"

            case .alwaysLight:
                currentSunriseText = "Always light"
                currentSunsetText = "Always light"
            }
        }
    }

    private func evaluateAndApply(for coordinate: CLLocationCoordinate2D?, at now: Date) {
        switch appearancePreference {
        case .forceLight:
            targetIsDarkMode = false
            nextTransitionText = "Forced Light mode"
            nextTransitionDate = nil
            applyAppearanceIfNeeded(darkMode: false)
            return

        case .forceDark:
            targetIsDarkMode = true
            nextTransitionText = "Forced Dark mode"
            nextTransitionDate = nil
            applyAppearanceIfNeeded(darkMode: true)
            return

        case .automatic:
            break
        }

        if automaticScheduleMode == .customTimes {
            let decision = AppearanceScheduleEngine.evaluateCustom(
                now: now,
                lightTime: Self.timeComponents(from: customLightTime),
                darkTime: Self.timeComponents(from: customDarkTime),
                calendar: .current
            )
            apply(decision: decision, now: now)
            return
        }

        guard let coordinate else {
            nextTransitionText = "Waiting for location"
            nextTransitionDate = nil
            return
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let decision = AppearanceScheduleEngine.evaluateSolar(
            now: now,
            today: SolarCalculator.solarDay(for: now, coordinate: coordinate),
            tomorrow: SolarCalculator.solarDay(for: tomorrow, coordinate: coordinate)
        )
        apply(decision: decision, now: now)
    }

    private func apply(decision: AutomaticAppearanceDecision, now: Date) {
        switch decision {
        case let .fixed(isDarkMode, message):
            targetIsDarkMode = isDarkMode
            nextTransitionText = message
            nextTransitionDate = nil
            applyAppearanceIfNeeded(darkMode: isDarkMode)

        case let .transition(currentIsDarkMode, nextTransition, nextIsDarkMode):
            if nextTransition <= now {
                let current = Self.systemIsCurrentlyDarkMode()
                targetIsDarkMode = current
                nextTransitionText = "Recalculating schedule..."
                nextTransitionDate = nextTransition
                return
            }
            targetIsDarkMode = currentIsDarkMode
            nextTransitionText = "Next: \(formatTime(nextTransition)) -> \(nextIsDarkMode ? "Dark" : "Light") mode"
            nextTransitionDate = nextTransition
            applyAppearanceIfNeeded(darkMode: currentIsDarkMode)
        }
    }

    private func scheduleNextRefresh(now: Date) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil

        var candidates: [Date] = []

        if appearancePreference == .automatic {
            if let nextTransitionDate {
                if nextTransitionDate > now {
                    staleTransitionRetryCount = 0
                    candidates.append(nextTransitionDate)
                } else {
                    staleTransitionRetryCount = min(staleTransitionRetryCount + 1, 6)
                    let retryDelaySeconds = min(60.0, pow(2.0, Double(staleTransitionRetryCount)))
                    candidates.append(now.addingTimeInterval(retryDelaySeconds))
                }
            }

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: now)
            if let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) {
                candidates.append(startOfTomorrow)
            }
        }

        if useAutomaticLocation,
           requiresLocationForActiveSchedule,
           let lastLocationRequestDate {
            candidates.append(lastLocationRequestDate.addingTimeInterval(60 * 30))
        }

        guard let nextRefreshDate = candidates.filter({ $0 > now }).min() else {
            return
        }

        let delay = nextRefreshDate.timeIntervalSince(now)
        let safeDelay = max(0.25, delay)

        scheduledRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(safeDelay))
            } catch {
                return
            }

            await MainActor.run {
                self?.refreshNow(forceLocation: false)
            }
        }
    }

    private func updateMenuBarCountdownText(now: Date) {
        guard shouldShowMenuBarCountdown,
              let nextTransitionDate,
              nextTransitionDate > now
        else {
            menuBarCountdownText = ""
            return
        }

        menuBarCountdownText = MenuBarStatusFormatter.remainingTime(until: nextTransitionDate, now: now)
    }

    private func scheduleMenuBarCountdownUpdate(now: Date) {
        menuBarCountdownTask?.cancel()
        menuBarCountdownTask = nil

        guard shouldShowMenuBarCountdown,
              let nextTransitionDate
        else {
            return
        }

        let nextUpdateDate = MenuBarStatusFormatter.nextCountdownUpdateDate(now: now, nextTransitionDate: nextTransitionDate)
        let delay = nextUpdateDate.timeIntervalSince(now)
        let safeDelay = max(0.25, delay)

        menuBarCountdownTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(safeDelay))
            } catch {
                return
            }

            await MainActor.run {
                guard let self else {
                    return
                }
                let now = Date()
                self.updateMenuBarCountdownText(now: now)
                self.scheduleMenuBarCountdownUpdate(now: now)
            }
        }
    }

    private func applyAppearanceIfNeeded(darkMode: Bool) {
        guard darkMode != Self.systemIsCurrentlyDarkMode() else {
            if !automationPermissionKnown {
                probeAndUpdateAutomationPermission()
            }
            errorText = nil
            return
        }

        if Self.setSystemDarkMode(darkMode) {
            automationPermissionKnown = true
            automationPermissionGranted = true
            errorText = nil
        } else {
            automationPermissionKnown = true
            automationPermissionGranted = false
            errorText = "Could not change appearance. Grant Automation permission for System Events."
        }
    }

    private static func probeAutomationPermission() -> Bool {
        let scriptSource = """
        tell application "System Events"
            tell appearance preferences
                return dark mode
            end tell
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            return false
        }

        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    private static func setSystemDarkMode(_ enabled: Bool) -> Bool {
        let scriptSource = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled ? "true" : "false")
            end tell
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            return false
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    private static func systemIsCurrentlyDarkMode() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func minutesSinceMidnight(for date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return max(0, min((hour * 60) + minute, 1439))
    }

    private static func dateFromMinutesSinceMidnight(_ minutes: Int, calendar: Calendar = .current) -> Date {
        let bounded = max(0, min(minutes, 1439))
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: bounded, to: startOfDay) ?? startOfDay
    }

    private static func timeComponents(from date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: date)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func storedCoordinateValue(defaults: UserDefaults, key: String) -> Double? {
        if let numeric = defaults.object(forKey: key) as? NSNumber {
            return numeric.doubleValue
        }

        if let text = defaults.string(forKey: key) {
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

@MainActor
extension ThemeController: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus

        if requiresLocationForActiveSchedule,
           manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }

        refreshNow(forceLocation: false)
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last?.coordinate {
            latestCoordinate = latest
            defaults.set(latest.latitude, forKey: Self.cachedLatitudeKey)
            defaults.set(latest.longitude, forKey: Self.cachedLongitudeKey)
            errorText = nil
            refreshNow(forceLocation: false)
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        if !requiresLocationForActiveSchedule {
            locationStatusText = "Location unavailable (not required in current mode)."
            return
        }

        if manualCoordinates != nil {
            locationStatusText = "Using manual coordinates (auto location unavailable)."
        } else {
            locationStatusText = "Location unavailable. Enter manual coordinates."
        }
    }
}
