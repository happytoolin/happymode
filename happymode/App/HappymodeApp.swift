import SwiftUI

@main
struct HappymodeApp: App {
    @StateObject private var statusItemController = StatusItemController()

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
