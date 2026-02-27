import AppKit
import SwiftUI

// MARK: - Shared helpers

private let paneWidth: CGFloat = 380

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    @ObservedObject var controller: ThemeController
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    @State private var showLaunchAtLoginErrorAlert = false
    @State private var launchAtLoginErrorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Appearance")

                HStack {
                    Text("Theme")
                    Spacer()
                    Picker("", selection: $controller.appearancePreference) {
                        ForEach(AppearancePreference.menuOrder) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                HStack {
                    Text("Current mode")
                    Spacer()
                    Text(controller.targetIsDarkMode ? "Dark" : "Light")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Menu Bar")

                Toggle("Show remaining time in menu bar", isOn: $controller.showRemainingTimeInMenuBar)

                HStack {
                    Text("Next switch")
                    Spacer()
                    Text(controller.nextTransitionText)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Startup")

                Toggle(
                    "Start happymode at login",
                    isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { newValue in
                            do {
                                try launchAtLoginController.setEnabled(newValue)
                            } catch {
                                launchAtLoginErrorMessage = error.localizedDescription
                                showLaunchAtLoginErrorAlert = true
                                launchAtLoginController.refresh()
                            }
                        }
                    )
                )

                if let hint = launchAtLoginController.statusHintText {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(launchAtLoginController.isAwaitingApproval ? Color.secondary : Color.orange)
                }
            }

            if let errorText = controller.errorText {
                Divider()
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(20)
        .frame(width: paneWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { launchAtLoginController.refresh() }
        .alert("Unable to Update Login Item", isPresented: $showLaunchAtLoginErrorAlert) {
            Button("OK") {}
        } message: {
            Text(launchAtLoginErrorMessage)
        }
    }
}

// MARK: - Schedule

struct ScheduleSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Schedule Source")

                HStack {
                    Text("Mode")
                    Spacer()
                    Picker("", selection: $controller.automaticScheduleMode) {
                        ForEach(AutomaticScheduleMode.menuOrder) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

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
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Weekly Preview")

                if controller.automaticScheduleMode == .customTimes {
                    Text("Hidden when using custom times.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if controller.weeklySolarDays.isEmpty {
                    Text("Available after location is resolved.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.weeklySolarDays) { day in
                        HStack {
                            Text(dayLabel(for: day.date))
                            Spacer()
                            Text(valueText(for: day.kind))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: paneWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month().day())
    }

    private func valueText(for kind: WeeklySolarKind) -> String {
        switch kind {
        case let .normal(sunrise, sunset):
            let sunriseText = sunrise.formatted(date: .omitted, time: .shortened)
            let sunsetText = sunset.formatted(date: .omitted, time: .shortened)
            return "\(sunriseText) – \(sunsetText)"
        case .alwaysDark:
            return "Polar night"
        case .alwaysLight:
            return "Midnight sun"
        }
    }
}

// MARK: - Location

struct LocationSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Automatic")

                Toggle("Use current location", isOn: $controller.useAutomaticLocation)

                if let detected = controller.detectedCoordinateText {
                    HStack {
                        Text("Detected")
                        Spacer()
                        Text(detected)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Source")
                    Spacer()
                    Text(controller.locationStatusText)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Manual Coordinates")

                HStack(spacing: 12) {
                    TextField(
                        "Latitude",
                        value: $controller.manualLatitude,
                        format: .number.precision(.fractionLength(0 ... 4))
                    )
                    .textFieldStyle(.roundedBorder)
                    TextField(
                        "Longitude",
                        value: $controller.manualLongitude,
                        format: .number.precision(.fractionLength(0 ... 4))
                    )
                    .textFieldStyle(.roundedBorder)
                }

                if controller.hasManualCoordinateInput && !controller.manualCoordinatesAreValid {
                    Text("Latitude must be –90…90, longitude –180…180.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Copy from detected") {
                    controller.fillManualCoordinatesFromDetected()
                }
                .controlSize(.small)
                .disabled(!controller.hasDetectedCoordinate)
            }
        }
        .padding(20)
        .frame(width: paneWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Permissions

struct PermissionsSettingsPane: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Required Access")

                PermissionRow(
                    title: "Location",
                    status: controller.locationPermissionText,
                    isComplete: controller.locationSetupComplete,
                    grantAction: { controller.requestLocationPermission() },
                    openAction: { controller.openLocationPrivacySettings() }
                )

                PermissionRow(
                    title: "Automation",
                    status: controller.automationPermissionText,
                    isComplete: controller.automationSetupComplete,
                    grantAction: { controller.requestAutomationPermission() },
                    openAction: { controller.openAutomationPrivacySettings() }
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Status")

                Label(controller.setupStatusText,
                      systemImage: controller.setupNeeded ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(controller.setupNeeded ? .orange : .green)

                Text(controller.setupGuidanceText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: paneWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - About

struct AboutSettingsPane: View {
    @ObservedObject var updateController: AppUpdateController

    private let githubURL = URL(string: "https://github.com/happytoolin/happymode")! // swiftlint:disable:this force_unwrapping
    private let websiteURL = URL(string: "https://happytoolin.com")! // swiftlint:disable:this force_unwrapping

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "happymode"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.5"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "5"
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)

            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 3) {
                Text(appName)
                    .font(.title3.bold())
                Text("Version \(appVersion) (\(appBuild))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Link("GitHub", destination: githubURL)
                Text("·").foregroundStyle(.quaternary)
                Link("Website", destination: websiteURL)
            }
            .font(.callout)

            Divider()
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                Button(updateController.isChecking ? "Checking…" : "Check for Updates…") {
                    updateController.checkForUpdates(userInitiated: true)
                }
                .controlSize(.regular)
                .disabled(updateController.isChecking)

                if updateController.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Spacer().frame(height: 4)
        }
        .padding(20)
        .frame(width: paneWidth)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let status: String
    let isComplete: Bool
    let grantAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? .green : .orange)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Grant", action: grantAction)
                .controlSize(.small)
            Button("Open Privacy", action: openAction)
                .controlSize(.small)
        }
    }
}
