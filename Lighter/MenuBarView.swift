import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Picker("Appearance", selection: $controller.appearancePreference) {
                ForEach(AppearancePreference.menuOrder) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            if controller.setupNeeded {
                setupBanner
            }

            modeSummaryChip

            if let errorText = controller.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            HStack(spacing: 10) {
                Button("Options...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: controller.targetIsDarkMode
                                ? [Color(red: 0.27, green: 0.35, blue: 0.58), Color(red: 0.12, green: 0.16, blue: 0.30)]
                                : [Color(red: 1.00, green: 0.82, blue: 0.20), Color(red: 0.97, green: 0.56, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)

                Image(systemName: controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(controller.targetIsDarkMode ? "Dark mode active" : "Light mode active")
                    .font(.headline)
                Text(controller.setupStatusText)
                    .font(.caption)
                    .foregroundStyle(controller.setupNeeded ? .orange : .secondary)
            }

            Spacer()
        }
    }

    private var setupBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Finish setup")
                    .font(.subheadline.weight(.semibold))
                Text(controller.setupGuidanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Open") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var modeSummaryChip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                metricValue(title: "Sunrise", value: controller.currentSunriseText, systemImage: "sunrise.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                metricValue(title: "Sunset", value: controller.currentSunsetText, systemImage: "sunset.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: summarySystemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("Condition")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(controller.appearancePreference.conditionTitle)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func metricValue(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.caption.weight(.semibold))
        }
    }

    private var summarySystemImage: String {
        switch controller.appearancePreference {
        case .forceLight:
            return "sun.max.fill"
        case .forceDark:
            return "moon.fill"
        case .automatic:
            return controller.targetIsDarkMode ? "sunrise.fill" : "sunset.fill"
        }
    }

}
