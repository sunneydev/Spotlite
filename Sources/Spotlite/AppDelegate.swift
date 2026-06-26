import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launcher: LauncherWindowController!
    private let scanner = AppScanner()
    private let hotKey = HotKey()
    private var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only ever run one Spotlite. If another copy is already running (e.g. an
        // older version still registered at login, or a duplicate launch after a
        // restart), the newest launch wins and the stale ones are terminated.
        guard enforceSingleInstance() else { return }

        // Menu bar item — custom magnifying-glass glyph matching the app icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuBarIcon()

        // Enable launch-at-login on first run; user can toggle it off via the menu.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didSetupLogin")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show (⌘Space)", action: #selector(toggle), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Rescan ~/Applications", action: #selector(rescan), keyEquivalent: "")
            .target = self
        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        updateLoginState()

        // Initial scan
        scanner.rescan()

        // Window controller
        launcher = LauncherWindowController(scanner: scanner)

        // Global hotkey: ⌘Space
        hotKey.register(keyCode: 49, modifiers: [.command]) { [weak self] in
            self?.toggle()
        }
    }

    /// Guarantees a single live Spotlite. Returns `true` if this process should keep
    /// running, `false` if it bowed out to a newer instance (and is terminating).
    ///
    /// Tiebreak by launch date, falling back to PID, so the decision is deterministic
    /// even when two copies launch simultaneously at login — exactly one survives.
    private func enforceSingleInstance() -> Bool {
        let me = NSRunningApplication.current
        let myExec = me.executableURL?.lastPathComponent
        let others = NSWorkspace.shared.runningApplications.filter { other in
            guard other.processIdentifier != me.processIdentifier else { return false }
            // Match siblings by bundle id, and also by executable name so a bare,
            // un-bundled dev binary (nil bundle id) still counts as a Spotlite.
            if other.bundleIdentifier == me.bundleIdentifier { return true }
            return myExec != nil && other.executableURL?.lastPathComponent == myExec
        }
        guard !others.isEmpty else { return true }

        let myDate = me.launchDate ?? .distantPast
        let newerExists = others.contains { other in
            let otherDate = other.launchDate ?? .distantPast
            return otherDate > myDate
                || (otherDate == myDate && other.processIdentifier > me.processIdentifier)
        }
        if newerExists {
            // A newer instance is taking over — defer to it.
            NSApp.terminate(nil)
            return false
        }

        // We're the newest launch: evict the stale ones and carry on.
        others.forEach { $0.terminate() }
        return true
    }

    @objc private func toggle() {
        launcher.toggle()
    }

    @objc private func rescan() {
        scanner.rescan()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Spotlite login item toggle failed: \(error)")
        }
        updateLoginState()
    }

    private func updateLoginState() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// A soft single sparkle — calm, elegant, and a quiet nod to the name.
    /// Template image so it adapts to light/dark menu bars.
    private static func menuBarIcon() -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let img = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Spotlite")?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = true
        return img ?? NSImage()
    }
}
