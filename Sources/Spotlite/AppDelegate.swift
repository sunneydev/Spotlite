import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launcher: LauncherWindowController!
    private let scanner = AppScanner()
    private let hotKey = HotKey()
    private var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    /// Magnifying glass drawn to match the app icon — a clean template image
    /// that adapts to light/dark menu bars. 18×18, crisp at any scale.
    private static func menuBarIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let lineWidth: CGFloat = 1.6
            let inset = lineWidth / 2 + 0.5
            NSColor.black.setStroke()

            let diameter = rect.width * 0.62
            let lens = NSRect(x: inset, y: rect.maxY - diameter - inset,
                              width: diameter, height: diameter)
            let ring = NSBezierPath(ovalIn: lens)
            ring.lineWidth = lineWidth
            ring.stroke()

            let r = diameter / 2
            let a: CGFloat = -.pi / 4
            let start = NSPoint(x: lens.midX + cos(a) * r, y: lens.midY + sin(a) * r)
            let handle = NSBezierPath()
            handle.move(to: start)
            handle.line(to: NSPoint(x: rect.maxX - inset, y: inset))
            handle.lineWidth = lineWidth + 0.4
            handle.lineCapStyle = .round
            handle.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }
}
