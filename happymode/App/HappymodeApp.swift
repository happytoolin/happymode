import AppKit
import SwiftUI

@main
struct HappymodeApp: App {
    @StateObject private var controller = ThemeController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                controller: controller,
                openSettingsWindow: {
                    SettingsWindowManager.shared.show(controller: controller)
                }
            )
        } label: {
            MenuBarStatusLabel(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowManager.shared.show(controller: controller)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(after: .appSettings) {
                Button("Refresh Now") {
                    controller.refreshNow(forceLocation: true)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
private final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var settingsWindow: NSWindow?

    private init() {}

    func show(controller: ThemeController) {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(controller: controller))
            hostingController.view.wantsLayer = true
            hostingController.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            let window = NSWindow(contentViewController: hostingController)
            window.title = "happymode Settings"
            window.setContentSize(NSSize(width: 860, height: 640))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isMovableByWindowBackground = false
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)

            if !controller.menuBarStatusText.isEmpty {
                Text(controller.menuBarStatusText)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("happymode")
        .accessibilityValue(accessibilityValue)
    }

    private var iconName: String {
        if controller.setupNeeded {
            return "exclamationmark.triangle.fill"
        }

        return controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill"
    }

    private var accessibilityValue: String {
        if controller.setupNeeded {
            return "Setup needed"
        }

        let mode = controller.targetIsDarkMode ? "Dark mode" : "Light mode"
        if controller.menuBarStatusText.isEmpty {
            return mode
        }

        return "\(mode), \(controller.menuBarStatusText) remaining"
    }
}
