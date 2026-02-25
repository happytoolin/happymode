import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsPane(controller: controller)
            }

            Tab("Schedule", systemImage: "clock") {
                ScheduleSettingsPane(controller: controller)
            }

            Tab("Location", systemImage: "location") {
                LocationSettingsPane(controller: controller)
            }

            Tab("Permissions", systemImage: "checkmark.shield") {
                PermissionsSettingsPane(controller: controller)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

struct GeneralSettingsPane: View {
    @ObservedObject var controller: ThemeController

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("happymode")
                            .font(.title3.bold())
                        Text("Version \(appVersion)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Appearance", selection: $controller.appearancePreference) {
                    ForEach(AppearancePreference.menuOrder) { preference in
                        Label(preference.title, systemImage: preference.systemImage)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent {
                    Text(controller.targetIsDarkMode ? "Dark" : "Light")
                } label: {
                    Label("Current mode", systemImage: "circle.lefthalf.filled")
                }
            } header: {
                Label("Appearance", systemImage: "sun.max")
            }

            Section {
                Toggle("Show remaining time in menu bar", isOn: $controller.showRemainingTimeInMenuBar)

                LabeledContent {
                    Text(controller.nextTransitionText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Next switch", systemImage: "timer")
                }
            } header: {
                Label("Menu Bar", systemImage: "menubar.rectangle")
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
    }
}

struct ScheduleSettingsPane: View {
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

struct LocationSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section {
                Toggle("Use current location", isOn: $controller.useAutomaticLocation)

                if let detected = controller.detectedCoordinateText {
                    LabeledContent("Detected", value: detected)
                }

                LabeledContent {
                    Text(controller.locationStatusText)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Source")
                }
            } header: {
                Label("Location", systemImage: "location")
            }

            Section {
                HStack(spacing: 12) {
                    TextField(
                        "Latitude",
                        value: $controller.manualLatitude,
                        format: .number.precision(.fractionLength(0 ... 4))
                    )
                    TextField(
                        "Longitude",
                        value: $controller.manualLongitude,
                        format: .number.precision(.fractionLength(0 ... 4))
                    )
                }

                if controller.hasManualCoordinateInput && !controller.manualCoordinatesAreValid {
                    Text("Latitude must be -90...90, longitude -180...180.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    Button("Copy from detected") {
                        controller.fillManualCoordinatesFromDetected()
                    }
                    .disabled(!controller.hasDetectedCoordinate)
                }
            } header: {
                Label("Manual Coordinates", systemImage: "map")
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionsSettingsPane: View {
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
