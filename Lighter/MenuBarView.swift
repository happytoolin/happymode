import AppKit
import Charts
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(controller.targetIsDarkMode ? "Dark mode active" : "Light mode active",
                  systemImage: controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.headline)

            Picker("Appearance", selection: $controller.appearancePreference) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            WeeklySunGraphView(days: controller.weeklySolarDays)

            HStack(spacing: 16) {
                Label(controller.currentSunriseText, systemImage: "sunrise.fill")
                Label(controller.currentSunsetText, systemImage: "sunset.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

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

            Divider()

            Button("Options...") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }

            Button("Quit Lighter") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 360)
    }
}

private struct WeeklySunGraphView: View {
    let days: [WeeklySolarDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("7-Day Sunlight Forecast")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if days.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.15, blue: 0.24), Color(red: 0.19, green: 0.31, blue: 0.49)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 168)
                    .overlay {
                        Text("Waiting for location")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
            } else {
                Chart {
                    ForEach(days) { day in
                        let label = shortWeekday(day.date)

                        switch day.kind {
                        case .normal(let sunrise, let sunset):
                            BarMark(
                                x: .value("Day", label),
                                yStart: .value("Sunrise", hourValue(sunrise)),
                                yEnd: .value("Sunset", hourValue(sunset)),
                                width: 16
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Day", label),
                                y: .value("Sunrise Line", hourValue(sunrise))
                            )
                            .foregroundStyle(Color.yellow.opacity(0.9))
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Day", label),
                                y: .value("Sunset Line", hourValue(sunset))
                            )
                            .foregroundStyle(Color.orange.opacity(0.9))
                            .interpolationMethod(.catmullRom)

                        case .alwaysLight:
                            BarMark(
                                x: .value("Day", label),
                                yStart: .value("Always Light Start", 0.0),
                                yEnd: .value("Always Light End", 24.0),
                                width: 16
                            )
                            .foregroundStyle(Color.yellow.opacity(0.55))

                        case .alwaysDark:
                            BarMark(
                                x: .value("Day", label),
                                yStart: .value("Always Dark Start", 11.5),
                                yEnd: .value("Always Dark End", 12.5),
                                width: 16
                            )
                            .foregroundStyle(Color.indigo.opacity(0.65))
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartYScale(domain: 0 ... 24)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                            .foregroundStyle(.white.opacity(0.25))
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text(hourLabel(hour))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.15, blue: 0.24), Color(red: 0.19, green: 0.31, blue: 0.49)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(height: 168)
            }
        }
    }

    private func hourValue(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        return hour + (minute / 60)
    }

    private func shortWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func hourLabel(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case 0:
            return "12a"
        case 6:
            return "6a"
        case 12:
            return "12p"
        case 18:
            return "6p"
        case 24:
            return "12a"
        default:
            return ""
        }
    }
}
