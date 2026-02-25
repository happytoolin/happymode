import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: ThemeController
    var onOpenSettings: () -> Void = {}

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
            }

            sectionCard(title: "Today") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next switch")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if controller.appearancePreference == .automatic,
                       let nextTransitionDate = controller.nextTransitionDate {
                        Text(nextTransitionDate, style: .timer)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    } else {
                        Text(controller.nextTransitionText)
                            .fontWeight(.semibold)
                    }
                }

                Divider()

                LabeledContent {
                    Text(controller.currentSunriseText)
                        .fontWeight(.semibold)
                } label: {
                    Label(controller.transitionStartTitle, systemImage: controller.transitionStartSymbol)
                        .foregroundStyle(.secondary)
                }

                LabeledContent {
                    Text(controller.currentSunsetText)
                        .fontWeight(.semibold)
                } label: {
                    Label(controller.transitionEndTitle, systemImage: controller.transitionEndSymbol)
                        .foregroundStyle(.secondary)
                }
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
                Button {
                    controller.refreshNow(forceLocation: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Spacer(minLength: 0)

                Button("Settings…", action: onOpenSettings)
                    .keyboardShortcut(",", modifiers: .command)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 320)
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
}
