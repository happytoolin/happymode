import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, ObservableObject {
    let controller = ThemeController()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        observeChanges()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                controller: controller,
                onOpenSettings: { [weak self] in
                    self?.dismissAndOpenSettings()
                }
            )
        )
    }

    // MARK: - Click Handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Right-Click Menu

    private func showContextMenu() {
        let menu = NSMenu()

        for pref in AppearancePreference.menuOrder {
            let item = NSMenuItem(title: pref.title, action: #selector(setAppearance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pref
            item.state = controller.appearancePreference == pref ? .on : .off
            item.image = NSImage(systemSymbolName: pref.systemImage, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit happymode", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func setAppearance(_ sender: NSMenuItem) {
        guard let pref = sender.representedObject as? AppearancePreference else { return }
        controller.appearancePreference = pref
    }

    @objc private func openSettings() {
        dismissAndOpenSettings()
    }

    private func dismissAndOpenSettings() {
        popover.performClose(nil)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(controller: controller)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "happymode Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Status Item Updates

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let iconName: String
        if controller.setupNeeded {
            iconName = "exclamationmark.triangle.fill"
        } else {
            iconName = controller.targetIsDarkMode ? "moon.fill" : "sun.max.fill"
        }

        button.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "happymode"
        )?.withSymbolConfiguration(
            .init(scale: .medium)
        )

        let countdown = controller.menuBarCountdownText
        button.title = countdown.isEmpty ? "" : " \(countdown)"
        button.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .semibold
        )
    }

    private func observeChanges() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)
    }
}
