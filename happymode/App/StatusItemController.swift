import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class StatusItemController: NSObject, ObservableObject {
    let controller = ThemeController()
    let updateController = AppUpdateController()
    let launchAtLoginController = LaunchAtLoginController()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        observeChanges()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateController.checkForUpdatesIfNeeded()
        }
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

        let checkUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)

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

    @objc private func checkForUpdates() {
        updateController.checkForUpdates(userInitiated: true)
    }

    private func dismissAndOpenSettings() {
        popover.performClose(nil)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar
        tabVC.title = "happymode"

        let tabs: [(String, String, NSViewController)] = [
            ("General", "gearshape", NSHostingController(rootView: GeneralSettingsPane(
                controller: controller,
                launchAtLoginController: launchAtLoginController
            ))),
            ("Schedule", "clock", NSHostingController(rootView: ScheduleSettingsPane(
                controller: controller
            ))),
            ("Location", "location", NSHostingController(rootView: LocationSettingsPane(
                controller: controller
            ))),
            ("Permissions", "checkmark.shield", NSHostingController(rootView: PermissionsSettingsPane(
                controller: controller
            ))),
            ("About", "info.circle", NSHostingController(rootView: AboutSettingsPane(
                updateController: updateController
            ))),
        ]

        for (title, icon, vc) in tabs {
            let item = NSTabViewItem(viewController: vc)
            item.label = title
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            tabVC.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabVC)
        window.styleMask = [.titled, .closable]
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered

    var isEnabled: Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    var isAwaitingApproval: Bool {
        status == .requiresApproval
    }

    var statusHintText: String? {
        switch status {
        case .enabled:
            return nil
        case .requiresApproval:
            return "Approve happymode in System Settings → General → Login Items to enable auto-start."
        case .notRegistered:
            return nil
        case .notFound:
            return "happymode can’t be registered as a login item (app bundle not found)."
        @unknown default:
            return "Login item status is unknown."
        }
    }

    init() {
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        refresh()
    }
}

@MainActor
final class AppUpdateController: ObservableObject {    @Published private(set) var isChecking = false

    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/happytoolin/happymode/releases/latest")!
    private static let lastCheckedDateKey = "happymode.update.lastCheckedDate"
    private static let githubUserAgent = "happymode-updater"

    private let session: URLSession
    private let defaults: UserDefaults
    private var hasPresentedAutomaticAlertThisLaunch = false

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    func checkForUpdatesIfNeeded() {
        if let lastChecked = defaults.object(forKey: Self.lastCheckedDateKey) as? Date,
           Calendar.current.isDate(lastChecked, inSameDayAs: Date()) {
            return
        }

        checkForUpdates(userInitiated: false)
    }

    func checkForUpdates(userInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isChecking = false }

            do {
                let release = try await self.fetchLatestRelease()
                self.defaults.set(Date(), forKey: Self.lastCheckedDateKey)
                self.handleReleaseCheckResult(release, userInitiated: userInitiated)
            } catch {
                guard userInitiated else { return }
                self.presentFailureAlert(message: error.localizedDescription)
            }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.githubUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw UpdateError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.invalidPayload
        }
    }

    private func handleReleaseCheckResult(_ release: GitHubRelease, userInitiated: Bool) {
        let currentVersion = normalizedVersionString(currentAppVersion)
        let latestVersion = normalizedVersionString(release.tagName)

        if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
            if !userInitiated && hasPresentedAutomaticAlertThisLaunch {
                return
            }

            hasPresentedAutomaticAlertThisLaunch = true
            presentUpdateAvailableAlert(
                latestVersion: latestVersion,
                currentVersion: currentVersion,
                releaseURL: release.releaseURL
            )
            return
        }

        if userInitiated {
            presentUpToDateAlert(version: currentVersion)
        }
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func normalizedVersionString(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("v") else {
            return trimmed
        }
        return String(trimmed.dropFirst())
    }

    private func presentUpdateAvailableAlert(latestVersion: String, currentVersion: String, releaseURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Available"
        alert.informativeText = "happymode \(latestVersion) is available. You are currently on \(currentVersion)."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func presentUpToDateAlert(version: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "You're Up to Date"
        alert.informativeText = "happymode \(version) is currently installed."
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }

    private func presentFailureAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = "Please try again later.\n\(message)"
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }

    private struct GitHubRelease: Decodable {
        private static let fallbackURL = URL(string: "https://github.com/happytoolin/happymode/releases/latest")!

        let tagName: String
        let htmlURLString: String?

        var releaseURL: URL {
            if let htmlURLString, let url = URL(string: htmlURLString) {
                return url
            }
            return Self.fallbackURL
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURLString = "html_url"
        }
    }

    private enum UpdateError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The update server returned an invalid response."
            case .httpStatus(let status):
                return "The update server returned status code \(status)."
            case .invalidPayload:
                return "The update data could not be read."
            }
        }
    }
}
