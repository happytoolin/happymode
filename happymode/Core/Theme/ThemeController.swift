import AppKit
import Combine
import CoreLocation
import Foundation

enum AppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case forceLight
    case forceDark

    static let menuOrder: [AppearancePreference] = [.forceDark, .automatic, .forceLight]

    var id: String { rawValue }

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

    var id: String { rawValue }

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
            switch tomorrow {
            case .normal(let nextSunrise, _):
                return .transition(currentIsDarkMode: true, nextTransition: nextSunrise, nextIsDarkMode: false)
            case .alwaysDark:
                return .fixed(isDarkMode: true, message: "Polar night: staying in Dark mode.")
            case .alwaysLight:
                return .transition(
                    currentIsDarkMode: true,
                    nextTransition: startOfTomorrow(from: now, calendar: calendar),
                    nextIsDarkMode: false
                )
            }

        case .alwaysLight:
            switch tomorrow {
            case .normal(_, let nextSunset):
                return .transition(currentIsDarkMode: false, nextTransition: nextSunset, nextIsDarkMode: true)
            case .alwaysDark:
                return .transition(
                    currentIsDarkMode: false,
                    nextTransition: startOfTomorrow(from: now, calendar: calendar),
                    nextIsDarkMode: true
                )
            case .alwaysLight:
                return .fixed(isDarkMode: false, message: "Midnight sun: staying in Light mode.")
            }

        case .normal(let sunrise, let sunset):
            if now < sunrise {
                return .transition(currentIsDarkMode: true, nextTransition: sunrise, nextIsDarkMode: false)
            }

            if now < sunset {
                return .transition(currentIsDarkMode: false, nextTransition: sunset, nextIsDarkMode: true)
            }

            switch tomorrow {
            case .normal(let nextSunrise, _):
                return .transition(currentIsDarkMode: true, nextTransition: nextSunrise, nextIsDarkMode: false)
            case .alwaysDark:
                return .fixed(isDarkMode: true, message: "Polar night: staying in Dark mode.")
            case .alwaysLight:
                return .transition(
                    currentIsDarkMode: true,
                    nextTransition: startOfTomorrow(from: now, calendar: calendar),
                    nextIsDarkMode: false
                )
            }
        }
    }

    private static func startOfTomorrow(from now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
    }

    static func evaluateCustom(now: Date,
                               lightTime: DateComponents,
                               darkTime: DateComponents,
                               calendar: Calendar = .current) -> AutomaticAppearanceDecision {
        guard let lightHour = lightTime.hour,
              let lightMinute = lightTime.minute,
              let darkHour = darkTime.hour,
              let darkMinute = darkTime.minute else {
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
            }) else {
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
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = .dropLeading
        return f
    }()

    static func remainingTime(until date: Date, now: Date) -> String {
        let interval = max(60, ceil(date.timeIntervalSince(now) / 60) * 60)
        return formatter.string(from: interval) ?? "0 min"
    }

    static func statusText(appearancePreference: AppearancePreference,
                            nextTransitionDate: Date?,
                            now: Date,
                            showRemainingTimeInMenuBar: Bool) -> String {
        guard showRemainingTimeInMenuBar else { return "" }
        guard appearancePreference == .automatic else { return "happymode" }
        guard let next = nextTransitionDate else { return "happymode" }
        return remainingTime(until: next, now: now)
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

    var id: Date { date }
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

    private static let defaultCustomLightMinutes = 7 * 60
    private static let defaultCustomDarkMinutes = 19 * 60

    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private var latestCoordinate: CLLocationCoordinate2D?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var menuBarCountdownTask: Task<Void, Never>?
    private var lastLocationRequestDate: Date?
    private var isBatchUpdatingManualCoordinates = false

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

        self.useAutomaticLocation = storedAutomatic
        self.appearancePreference = storedPreference
        self.automaticScheduleMode = storedScheduleMode
        self.customLightTime = Self.dateFromMinutesSinceMidnight(storedLightMinutes)
        self.customDarkTime = Self.dateFromMinutesSinceMidnight(storedDarkMinutes)
        self.showRemainingTimeInMenuBar = storedShowRemainingTime
        self.manualLatitude = storedLatitude
        self.manualLongitude = storedLongitude
        self.targetIsDarkMode = Self.systemIsCurrentlyDarkMode()
        self.locationAuthorizationStatus = CLLocationManager().authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )

        refreshNow(forceLocation: true)
    }

    deinit {
        scheduledRefreshTask?.cancel()
        menuBarCountdownTask?.cancel()
    }

    @objc private func calendarDayChanged() {
        refreshNow(forceLocation: true)
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
        if Self.probeAutomationPermission() {
            automationPermissionKnown = true
            automationPermissionGranted = true
            errorText = nil
        } else {
            automationPermissionKnown = true
            automationPermissionGranted = false
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

        if useAutomaticLocation && requiresLocationForActiveSchedule {
            requestLocationIfPossible(force: forceLocation)
        }

        let coordinate = resolvedCoordinate()

        if automaticScheduleMode == .sunriseSunset {
            if let coordinate {
                if latestCoordinate != nil && useAutomaticLocation {
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
        if useAutomaticLocation {
            if let detected = latestCoordinate {
                return detected
            }
            return manualCoordinates
        }
        return manualCoordinates
    }

    private var manualCoordinates: CLLocationCoordinate2D? {
        guard let latitude = manualLatitude,
              let longitude = manualLongitude,
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func updateWeeklyForecast(for coordinate: CLLocationCoordinate2D, from date: Date) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)

        var days: [WeeklySolarDay] = []

        for offset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }

            switch SolarCalculator.solarDay(for: dayDate, coordinate: coordinate) {
            case .normal(let sunrise, let sunset):
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
            case .normal(let sunrise, let sunset):
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
        case .fixed(let isDarkMode, let message):
            targetIsDarkMode = isDarkMode
            nextTransitionText = message
            nextTransitionDate = nil
            applyAppearanceIfNeeded(darkMode: isDarkMode)

        case .transition(let currentIsDarkMode, let nextTransition, let nextIsDarkMode):
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

        if appearancePreference == .automatic, let nextTransitionDate {
            candidates.append(nextTransitionDate)
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
        guard delay > 0 else {
            refreshNow(forceLocation: false)
            return
        }

        scheduledRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
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
              let nextTransitionDate else {
            menuBarCountdownText = ""
            return
        }

        menuBarCountdownText = MenuBarStatusFormatter.remainingTime(until: nextTransitionDate, now: now)
    }

    private func scheduleMenuBarCountdownUpdate(now: Date) {
        menuBarCountdownTask?.cancel()
        menuBarCountdownTask = nil

        guard shouldShowMenuBarCountdown,
              let nextTransitionDate else {
            return
        }

        let remainder = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
        let secondsToNextMinute = remainder == 0 ? 60 : 60 - remainder
        let nextUpdateDate = min(nextTransitionDate, now.addingTimeInterval(secondsToNextMinute))
        let delay = nextUpdateDate.timeIntervalSince(now)

        guard delay > 0 else {
            let current = Date()
            updateMenuBarCountdownText(now: current)
            scheduleMenuBarCountdownUpdate(now: current)
            return
        }

        menuBarCountdownTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
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

        if requiresLocationForActiveSchedule &&
            (manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways) {
            manager.requestLocation()
        }

        refreshNow(forceLocation: false)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last?.coordinate {
            latestCoordinate = latest
            errorText = nil
            refreshNow(forceLocation: false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
