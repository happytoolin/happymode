import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Picker("Appearance", selection: $controller.appearancePreference) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            if controller.setupNeeded {
                setupBanner
            }

            WeeklyDaylightTimelineView(days: controller.weeklySolarDays)

            HStack(spacing: 10) {
                metricChip(title: "Sunrise", value: controller.currentSunriseText, systemImage: "sunrise.fill")
                metricChip(title: "Sunset", value: controller.currentSunsetText, systemImage: "sunset.fill")
            }

            Text(controller.nextTransitionText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(controller.locationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

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
        .frame(width: 380)
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

    private func metricChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.secondary.opacity(0.10))
        )
    }
}

private struct WeeklyDaylightTimelineView: View {
    let days: [WeeklySolarDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Daylight")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 7) {
                if days.isEmpty {
                    Text("Waiting for location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    ForEach(days) { day in
                        DaylightTrackRow(day: day)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.07, green: 0.13, blue: 0.26), Color(red: 0.15, green: 0.26, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }
}

private struct DaylightTrackRow: View {
    let day: WeeklySolarDay

    var body: some View {
        HStack(spacing: 10) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, alignment: .leading)

            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.32))
                        .frame(height: 14)

                    switch day.kind {
                    case .normal(let sunrise, let sunset):
                        let start = max(0, min(1, hourValue(sunrise) / 24))
                        let end = max(0, min(1, hourValue(sunset) / 24))
                        let daylightWidth = max((end - start) * width, 2)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.88, blue: 0.26), Color(red: 0.98, green: 0.57, blue: 0.19)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: daylightWidth, height: 14)
                            .offset(x: start * width)

                    case .alwaysLight:
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.90, blue: 0.45), Color(red: 1.00, green: 0.73, blue: 0.33)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 14)

                    case .alwaysDark:
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.leading, 4)
                    }
                }
            }
            .frame(height: 14)

            Text(daySummary(day))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 90, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private func hourValue(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + (Double(components.minute ?? 0) / 60)
    }

    private func daySummary(_ day: WeeklySolarDay) -> String {
        switch day.kind {
        case .normal(let sunrise, let sunset):
            return "\(shortTime(sunrise)) - \(shortTime(sunset))"
        case .alwaysLight:
            return "All day"
        case .alwaysDark:
            return "No sun"
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
