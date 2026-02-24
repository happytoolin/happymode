import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $controller.appearancePreference) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Text(controller.appearanceDescriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Location") {
                Toggle("Use current location", isOn: $controller.useAutomaticLocation)

                if let detectedCoordinateText = controller.detectedCoordinateText {
                    Text("Detected coordinates: \(detectedCoordinateText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Latitude", text: $controller.manualLatitudeText)
                        .textFieldStyle(.roundedBorder)

                    TextField("Longitude", text: $controller.manualLongitudeText)
                        .textFieldStyle(.roundedBorder)

                    Button("Use detected") {
                        controller.fillManualCoordinatesFromDetected()
                    }
                    .disabled(!controller.hasDetectedCoordinate)
                }

                if (!controller.manualLatitudeText.isEmpty || !controller.manualLongitudeText.isEmpty) && !controller.manualCoordinatesAreValid {
                    Text("Enter valid coordinates: latitude -90...90, longitude -180...180.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Manual coordinates are used when automatic location is disabled, or as fallback if location access fails.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Refresh current location") {
                    controller.refreshNow(forceLocation: true)
                }
                .disabled(!controller.useAutomaticLocation)
            }

            Section("Status") {
                Text(controller.nextTransitionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(controller.locationStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorText = controller.errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 540)
    }
}
