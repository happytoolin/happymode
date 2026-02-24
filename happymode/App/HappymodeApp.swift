import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let happymodeOpenSettingsRequested = Notification.Name("happymodeOpenSettingsRequested")
}

@main
struct HappymodeApp: App {
    @StateObject private var controller: ThemeController
    private let statusBarController: StatusBarController

    init() {
        let themeController = ThemeController()
        _controller = StateObject(wrappedValue: themeController)
        statusBarController = StatusBarController(themeController: themeController)
    }

    var body: some Scene {
        Settings {
            SettingsView(controller: controller)
        }
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let themeController: ThemeController
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(themeController: ThemeController) {
        self.themeController = themeController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configurePopover()
        configureStatusItemButton()
        bindController()
        observeSettingsRequests()
        updateStatusItemAppearance()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 320)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(controller: themeController))
    }

    private func configureStatusItemButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    private func bindController() {
        themeController.$menuBarStatusText
            .combineLatest(themeController.$targetIsDarkMode)
            .sink { [weak self] _, _ in
                self?.updateStatusItemAppearance()
            }
            .store(in: &cancellables)
    }

    private func observeSettingsRequests() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsRequest),
            name: .happymodeOpenSettingsRequested,
            object: nil
        )
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else {
            return
        }

        button.title = themeController.menuBarStatusText
        button.image = NSImage(
            systemSymbolName: themeController.targetIsDarkMode ? "moon.fill" : "sun.max.fill",
            accessibilityDescription: nil
        )
        button.image?.isTemplate = true
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(relativeTo: sender)
            return
        }

        if event.type == .rightMouseUp {
            popover.performClose(nil)
            showContextMenu()
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Options...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshNow() {
        themeController.refreshNow(forceLocation: true)
    }

    @objc private func openSettings() {
        showSettingsWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func handleOpenSettingsRequest() {
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(controller: themeController))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "happymode Options"
            window.setContentSize(NSSize(width: 680, height: 620))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
