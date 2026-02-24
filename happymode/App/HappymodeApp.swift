import SwiftUI

@main
struct HappymodeApp: App {
    @StateObject private var controller = ThemeController()

    var body: some Scene {
        MenuBarExtra("happymode", systemImage: controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller)
        }
    }
}
