import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                appearanceModeControl
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
            )

            if controller.setupNeeded {
                setupBanner
            }

            modeSummaryChip

            if let errorText = controller.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button("Options...") {
                    controller.openAppSettings()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .frame(width: 320)
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
                if controller.setupNeeded {
                    Text("Setup needed")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
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
                controller.openAppSettings()
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
                metricValue(title: controller.transitionStartTitle,
                            value: controller.currentSunriseText,
                            systemImage: controller.transitionStartSymbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
                metricValue(title: controller.transitionEndTitle,
                            value: controller.currentSunsetText,
                            systemImage: controller.transitionEndSymbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)

            Divider()

            Text(scheduleSummaryTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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

    private var scheduleSummaryTitle: String {
        switch controller.automaticScheduleMode {
        case .sunriseSunset:
            return "Sunrise and sunset"
        case .customTimes:
            return "Custom light/dark times"
        }
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

    private var appearanceModeControl: some View {
        HStack(spacing: 6) {
            ForEach(AppearancePreference.menuOrder) { preference in
                Button {
                    controller.appearancePreference = preference
                } label: {
                    Text(preference.title)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(controller.appearancePreference == preference ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(controller.appearancePreference == preference ? Color.accentColor : Color.secondary.opacity(0.16))
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
        )
    }

}
