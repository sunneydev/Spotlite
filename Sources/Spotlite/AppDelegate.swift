import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launcher: LauncherWindowController!
    private let scanner = AppScanner()
    private let hotKey = HotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar item — minimal, monochrome symbol
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "sparkle.magnifyingglass",
                              accessibilityDescription: "Spotlite")
            img?.isTemplate = true
            button.image = img
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show (⌘Space)", action: #selector(toggle), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Rescan ~/Applications", action: #selector(rescan), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

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
}
