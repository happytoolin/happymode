import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController
    let openSettingsWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            sectionCard(title: "Mode") {
                Picker("Appearance", selection: $controller.appearancePreference) {
                    ForEach(AppearancePreference.menuOrder) { preference in
                        Label(preference.title, systemImage: preference.systemImage)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show countdown in menu bar", isOn: $controller.showRemainingTimeInMenuBar)
                    .toggleStyle(.switch)
            }

            sectionCard(title: "Today") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next switch")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(controller.nextTransitionRemainingText)
                        .fontWeight(.semibold)
                }

                Divider()

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
            }

            if controller.setupNeeded {
                sectionCard(title: "Action Needed") {
                    Label(controller.setupGuidanceText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }

            if let errorText = controller.errorText {
                sectionCard(title: "Error") {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            HStack(spacing: 8) {
                Button("Refresh") {
                    controller.refreshNow(forceLocation: true)
                }

                Spacer(minLength: 0)

                Button("Settings…") {
                    openSettingsWindow()
                }

                Button("Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 380)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(controller.targetIsDarkMode ? "Dark mode active" : "Light mode active")
                    .font(.headline)
                Text(controller.appearanceDescriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if controller.setupNeeded {
                Label("Needs setup", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private func sectionCard<Content: View>(title: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    private func statusRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
