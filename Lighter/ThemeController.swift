import AppKit
import Combine
import CoreLocation
import Foundation

enum AppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case forceLight
    case forceDark

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
            if useAutomaticLocation {
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

    @Published var manualLatitudeText: String {
        didSet {
            defaults.set(manualLatitudeText, forKey: Self.manualLatitudeKey)
            refreshNow(forceLocation: false)
        }
    }

    @Published var manualLongitudeText: String {
        didSet {
            defaults.set(manualLongitudeText, forKey: Self.manualLongitudeKey)
            refreshNow(forceLocation: false)
        }
    }

    @Published private(set) var targetIsDarkMode: Bool
    @Published private(set) var nextTransitionText: String = "Calculating schedule..."
    @Published private(set) var locationStatusText: String = "Detecting location..."
    @Published private(set) var currentSunriseText: String = "--"
    @Published private(set) var currentSunsetText: String = "--"
    @Published private(set) var weeklySolarDays: [WeeklySolarDay] = []
    @Published private(set) var errorText: String?

    var manualCoordinatesAreValid: Bool {
        manualCoordinates != nil
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
            return "Automatic uses sunrise and sunset times."
        case .forceLight:
            return "Forced Light mode ignores sunrise/sunset until switched back to Auto."
        case .forceDark:
            return "Forced Dark mode ignores sunrise/sunset until switched back to Auto."
        }
    }

    private static let automaticLocationKey = "useAutomaticLocation"
    private static let appearancePreferenceKey = "appearancePreference"
    private static let manualLatitudeKey = "manualLatitude"
    private static let manualLongitudeKey = "manualLongitude"

    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private var latestCoordinate: CLLocationCoordinate2D?
    private var timer: Timer?
    private var lastLocationRequestDate: Date?

    override init() {
        let storedAutomatic = defaults.object(forKey: Self.automaticLocationKey) as? Bool ?? true
        let storedPreference = AppearancePreference(rawValue: defaults.string(forKey: Self.appearancePreferenceKey) ?? "") ?? .automatic
        let storedLatitude = defaults.string(forKey: Self.manualLatitudeKey) ?? ""
        let storedLongitude = defaults.string(forKey: Self.manualLongitudeKey) ?? ""

        self.useAutomaticLocation = storedAutomatic
        self.appearancePreference = storedPreference
        self.manualLatitudeText = storedLatitude
        self.manualLongitudeText = storedLongitude
        self.targetIsDarkMode = Self.systemIsCurrentlyDarkMode()

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow(forceLocation: false)
            }
        }

        refreshNow(forceLocation: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    @objc private func calendarDayChanged() {
        refreshNow(forceLocation: true)
    }

    func fillManualCoordinatesFromDetected() {
        guard let coordinate = latestCoordinate else {
            return
        }

        manualLatitudeText = String(format: "%.6f", coordinate.latitude)
        manualLongitudeText = String(format: "%.6f", coordinate.longitude)
    }

    func refreshNow(forceLocation: Bool) {
        if useAutomaticLocation {
            requestLocationIfPossible(force: forceLocation)
        }

        guard let coordinate = resolvedCoordinate() else {
            nextTransitionText = "Waiting for location"
            locationStatusText = useAutomaticLocation
                ? "Allow location access or enter manual coordinates."
                : "Enter manual coordinates."
            currentSunriseText = "--"
            currentSunsetText = "--"
            weeklySolarDays = []
            return
        }

        locationStatusText = "Using location: \(formatCoordinate(coordinate.latitude)), \(formatCoordinate(coordinate.longitude))"
        updateWeeklyForecast(for: coordinate, from: Date())
        evaluateAndApply(for: coordinate, at: Date())
    }

    private func requestLocationIfPossible(force: Bool) {
        let status = locationManager.authorizationStatus

        switch status {
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
        guard let latitude = Double(manualLatitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let longitude = Double(manualLongitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
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

    private func evaluateAndApply(for coordinate: CLLocationCoordinate2D, at now: Date) {
        switch appearancePreference {
        case .forceLight:
            targetIsDarkMode = false
            nextTransitionText = "Forced Light mode"
            applyAppearanceIfNeeded(darkMode: false)
            return

        case .forceDark:
            targetIsDarkMode = true
            nextTransitionText = "Forced Dark mode"
            applyAppearanceIfNeeded(darkMode: true)
            return

        case .automatic:
            break
        }

        let todaySolar = SolarCalculator.solarDay(for: now, coordinate: coordinate)

        switch todaySolar {
        case .alwaysDark:
            targetIsDarkMode = true
            nextTransitionText = "Polar night: staying in Dark mode."
            applyAppearanceIfNeeded(darkMode: true)

        case .alwaysLight:
            targetIsDarkMode = false
            nextTransitionText = "Midnight sun: staying in Light mode."
            applyAppearanceIfNeeded(darkMode: false)

        case .normal(let sunrise, let sunset):
            if now < sunrise {
                targetIsDarkMode = true
                nextTransitionText = "Next: \(formatTime(sunrise)) -> Light mode"
                applyAppearanceIfNeeded(darkMode: true)
            } else if now < sunset {
                targetIsDarkMode = false
                nextTransitionText = "Next: \(formatTime(sunset)) -> Dark mode"
                applyAppearanceIfNeeded(darkMode: false)
            } else {
                targetIsDarkMode = true
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
                let tomorrowSolar = SolarCalculator.solarDay(for: tomorrow, coordinate: coordinate)

                switch tomorrowSolar {
                case .normal(let nextSunrise, _):
                    nextTransitionText = "Next: \(formatTime(nextSunrise)) -> Light mode"
                case .alwaysDark:
                    nextTransitionText = "Polar night: staying in Dark mode."
                case .alwaysLight:
                    nextTransitionText = "Midnight sun tomorrow: Light mode."
                }

                applyAppearanceIfNeeded(darkMode: true)
            }
        }
    }

    private func applyAppearanceIfNeeded(darkMode: Bool) {
        guard darkMode != Self.systemIsCurrentlyDarkMode() else {
            errorText = nil
            return
        }

        if Self.setSystemDarkMode(darkMode) {
            errorText = nil
        } else {
            errorText = "Could not change appearance. Grant Automation permission for System Events."
        }
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
        let globalDomain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let style = globalDomain?["AppleInterfaceStyle"] as? String
        return style == "Dark"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

@MainActor
extension ThemeController: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways {
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
        if manualCoordinates != nil {
            locationStatusText = "Using manual coordinates (auto location unavailable)."
        } else {
            locationStatusText = "Location unavailable. Enter manual coordinates."
        }
    }
}
