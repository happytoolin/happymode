import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case schedule
    case location
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .schedule:
            return "Schedule"
        case .location:
            return "Location"
        case .permissions:
            return "Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .schedule:
            return "clock"
        case .location:
            return "location"
        case .permissions:
            return "checkmark.shield"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var controller: ThemeController
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Picker("Section", selection: $selectedTab) {
                        ForEach(SettingsTab.allCases) { tab in
                            Label(tab.title, systemImage: tab.systemImage)
                                .labelStyle(.titleAndIcon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        controller.refreshNow(forceLocation: true)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 6)

                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsPane(controller: controller)
                    case .schedule:
                        ScheduleSettingsPane(controller: controller)
                    case .location:
                        LocationSettingsPane(controller: controller)
                    case .permissions:
                        PermissionsSettingsPane(controller: controller)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 600)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $controller.appearancePreference) {
                    ForEach(AppearancePreference.menuOrder) { preference in
                        Label(preference.title, systemImage: preference.systemImage)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show remaining time in menu bar", isOn: $controller.showRemainingTimeInMenuBar)

                LabeledContent {
                    Text(controller.targetIsDarkMode ? "Dark" : "Light")
                } label: {
                    Label("Current mode", systemImage: "circle.lefthalf.filled")
                }

                LabeledContent {
                    Text(controller.appearanceDescriptionText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Description", systemImage: "text.alignleft")
                }
            } header: {
                Label("Appearance", systemImage: "sun.max")
            }

            Section {
                LabeledContent {
                    Text(controller.nextTransitionText)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Next switch", systemImage: "timer")
                }

                statusRow(
                    title: controller.transitionStartTitle,
                    value: controller.currentSunriseText,
                    systemImage: controller.transitionStartSymbol
                )
                statusRow(
                    title: controller.transitionEndTitle,
                    value: controller.currentSunsetText,
                    systemImage: controller.transitionEndSymbol
                )

                LabeledContent {
                    Text(controller.locationStatusText)
                } label: {
                    Label("Location status", systemImage: "location.circle")
                }

                if let activeCoordinate = controller.activeCoordinateText {
                    LabeledContent {
                        Text(activeCoordinate)
                    } label: {
                        Label("Active coordinates", systemImage: "map")
                    }
                }
            } header: {
                Label("Status", systemImage: "waveform.path.ecg")
            }

            if let errorText = controller.errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                } header: {
                    Label("Error", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, -6)
    }

    private func statusRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ScheduleSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section {
                Picker("Automatic schedule", selection: $controller.automaticScheduleMode) {
                    ForEach(AutomaticScheduleMode.menuOrder) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if controller.automaticScheduleMode == .customTimes {
                    DatePicker("Light at",
                               selection: $controller.customLightTime,
                               displayedComponents: .hourAndMinute)
                    DatePicker("Dark at",
                               selection: $controller.customDarkTime,
                               displayedComponents: .hourAndMinute)

                    Text("Custom times run daily in your current macOS time zone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Schedule Source", systemImage: "calendar.badge.clock")
            }

            Section {
                ForEach(controller.weeklySolarDays) { day in
                    LabeledContent(dayLabel(for: day.date)) {
                        Text(valueText(for: day.kind))
                            .multilineTextAlignment(.trailing)
                    }
                }

                if controller.automaticScheduleMode == .customTimes {
                    Text("Weekly solar preview is hidden when using custom times.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if controller.weeklySolarDays.isEmpty {
                    Text("Solar preview becomes available after location is resolved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Weekly Preview", systemImage: "calendar")
            }
        }
        .formStyle(.grouped)
        .padding(.top, -6)
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month().day())
    }

    private func valueText(for kind: WeeklySolarKind) -> String {
        switch kind {
        case .normal(let sunrise, let sunset):
            let sunriseText = sunrise.formatted(date: .omitted, time: .shortened)
            let sunsetText = sunset.formatted(date: .omitted, time: .shortened)
            return "\(sunriseText) - \(sunsetText)"
        case .alwaysDark:
            return "Polar night"
        case .alwaysLight:
            return "Midnight sun"
        }
    }
}

private struct LocationSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section {
                Toggle("Use current location", isOn: $controller.useAutomaticLocation)

                if let detected = controller.detectedCoordinateText {
                    LabeledContent("Detected", value: detected)
                }

                HStack(spacing: 12) {
                    TextField("Latitude", text: $controller.manualLatitudeText)
                    TextField("Longitude", text: $controller.manualLongitudeText)
                }

                if (!controller.manualLatitudeText.isEmpty || !controller.manualLongitudeText.isEmpty) && !controller.manualCoordinatesAreValid {
                    Text("Coordinates must be valid: latitude -90...90 and longitude -180...180.")
                        .foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    Button("Use detected") {
                        controller.fillManualCoordinatesFromDetected()
                    }
                    .disabled(!controller.hasDetectedCoordinate)

                    Button("Refresh current location") {
                        controller.refreshNow(forceLocation: true)
                    }
                    .disabled(!controller.useAutomaticLocation)
                }
            } header: {
                Label("Coordinates", systemImage: "location")
            }

            Section {
                LabeledContent {
                    Text(controller.locationStatusText)
                } label: {
                    Label("Resolved source", systemImage: "scope")
                }

                LabeledContent {
                    Text(controller.locationPermissionText)
                } label: {
                    Label("Permission", systemImage: "lock.shield")
                }

                Button("Open Location Privacy") {
                    controller.openLocationPrivacySettings()
                }
            } header: {
                Label("Location Status", systemImage: "location.circle")
            }
        }
        .formStyle(.grouped)
        .padding(.top, -6)
    }
}

private struct PermissionsSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section {
                PermissionStatusRow(
                    title: "Location",
                    status: controller.locationPermissionText,
                    isComplete: controller.locationSetupComplete,
                    primaryActionLabel: "Grant Access",
                    primaryAction: { controller.requestLocationPermission() },
                    secondaryActionLabel: "Open Privacy",
                    secondaryAction: { controller.openLocationPrivacySettings() }
                )

                PermissionStatusRow(
                    title: "Automation",
                    status: controller.automationPermissionText,
                    isComplete: controller.automationSetupComplete,
                    primaryActionLabel: "Grant Access",
                    primaryAction: { controller.requestAutomationPermission() },
                    secondaryActionLabel: "Open Privacy",
                    secondaryAction: { controller.openAutomationPrivacySettings() }
                )
            } header: {
                Label("Required Access", systemImage: "checkmark.shield")
            }

            Section {
                Label(controller.setupStatusText,
                      systemImage: controller.setupNeeded ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(controller.setupNeeded ? .orange : .green)

                Text(controller.setupGuidanceText)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Setup Status", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .padding(.top, -6)
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let status: String
    let isComplete: Bool
    let primaryActionLabel: String
    let primaryAction: () -> Void
    let secondaryActionLabel: String
    let secondaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? .green : .orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(primaryActionLabel, action: primaryAction)
                    .buttonStyle(.borderedProminent)

                Button(secondaryActionLabel, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
