import SwiftUI

@main
struct LighterApp: App {
    @StateObject private var controller = ThemeController()

    var body: some Scene {
        MenuBarExtra("Lighter", systemImage: controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller)
        }
    }
}
