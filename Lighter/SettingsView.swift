import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                dashboardCard
                permissionsCard
                locationCard

                if let errorText = controller.errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 620, minHeight: 560)
    }

    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lighter Options")
                    .font(.title3.weight(.semibold))
                Text("Set mode, permissions, and location source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(controller.setupStatusText)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(controller.setupNeeded ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                )
                .foregroundStyle(controller.setupNeeded ? .orange : .green)
        }
    }

    private var dashboardCard: some View {
        card(title: "Dashboard") {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Active coordinates", value: controller.activeCoordinateText ?? "Unavailable")
                infoRow(label: "Next switch", value: controller.nextTransitionText)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Mode", selection: $controller.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var permissionsCard: some View {
        card(title: "Permissions") {
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "Location",
                    status: controller.locationPermissionText,
                    complete: controller.locationSetupComplete,
                    grantAction: { controller.requestLocationPermission() },
                    openAction: { controller.openLocationPrivacySettings() }
                )

                permissionRow(
                    title: "Automation",
                    status: controller.automationPermissionText,
                    complete: controller.automationSetupComplete,
                    grantAction: { controller.requestAutomationPermission() },
                    openAction: { controller.openAutomationPrivacySettings() }
                )
            }
        }
    }

    private var locationCard: some View {
        card(title: "Current Location") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Use current location", isOn: $controller.useAutomaticLocation)

                if let detected = controller.detectedCoordinateText {
                    infoRow(label: "Detected coordinates", value: detected)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latitude")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("25.000000", text: $controller.manualLatitudeText)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Longitude")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("80.000000", text: $controller.manualLongitudeText)
                                .textFieldStyle(.roundedBorder)
                        }
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
                }

                if (!controller.manualLatitudeText.isEmpty || !controller.manualLongitudeText.isEmpty) && !controller.manualCoordinatesAreValid {
                    Text("Coordinates must be valid: latitude -90...90 and longitude -180...180.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Use detected copies your latest detected coordinates into the manual fields.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(value)
                .font(.callout)
        }
    }

    private func permissionRow(title: String,
                               status: String,
                               complete: Bool,
                               grantAction: @escaping () -> Void,
                               openAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: complete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(complete ? .green : .orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Grant", action: grantAction)
                    .buttonStyle(.borderedProminent)

                Button("Open Privacy", action: openAction)
                    .buttonStyle(.bordered)
            }
        }
    }
}
