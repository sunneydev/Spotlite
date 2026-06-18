import AppKit

final class AppEntry: Hashable {
    enum Kind { case app, settings }

    let name: String
    let url: URL          // app bundle URL, or an x-apple.systempreferences: URL
    let lowerName: String
    let icon: NSImage
    let kind: Kind

    /// An installed application.
    init(url: URL) {
        self.url = url
        self.kind = .app
        let name = url.deletingPathExtension().lastPathComponent
        self.name = name
        self.lowerName = name.lowercased()
        // Pre-cache the icon — the expensive bit, done once at scan time.
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 40, height: 40)
        self.icon = icon
    }

    /// A System Settings section, opened via its URL scheme.
    init(settings name: String, symbol: String, tint: NSColor, urlString: String) {
        self.name = name
        self.lowerName = name.lowercased()
        self.url = URL(string: urlString)!
        self.kind = .settings
        self.icon = AppEntry.settingsIcon(symbol: symbol, tint: tint)
    }

    static func == (l: AppEntry, r: AppEntry) -> Bool { l.url == r.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    /// A macOS-style rounded, tinted icon with a white SF Symbol.
    private static func settingsIcon(symbol: String, tint: NSColor) -> NSImage {
        let size: CGFloat = 40
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
            let top = tint.blended(withFraction: 0.18, of: .white) ?? tint
            NSGradient(colors: [top, tint])!.draw(in: path, angle: -90)

            let cfg = NSImage.SymbolConfiguration(pointSize: 21, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            if let sym = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) {
                let s = sym.size
                sym.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2,
                                    width: s.width, height: s.height))
            }
            return true
        }
    }
}

final class AppScanner {
    private(set) var apps: [AppEntry] = []
    let settings: [AppEntry] = AppScanner.makeSettings()

    private var roots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
        ]
    }

    func rescan() {
        let fm = FileManager.default
        var seen = Set<String>()
        var found: [AppEntry] = []
        for root in roots {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    let key = url.deletingPathExtension().lastPathComponent.lowercased()
                    if seen.insert(key).inserted {
                        found.append(AppEntry(url: url))
                    }
                    enumerator.skipDescendants()
                }
            }
        }
        found.sort { $0.lowerName < $1.lowerName }
        self.apps = found
    }

    func search(_ query: String, limit: Int = 6) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        // Empty query → top apps only; settings would just be clutter.
        if q.isEmpty { return Array(apps.prefix(limit)) }

        let qFirst = q.first!
        var scored: [(AppEntry, Int)] = []
        scored.reserveCapacity(64)
        for entry in apps + settings {
            // Cheap reject: query's first char must appear somewhere.
            if !entry.lowerName.contains(qFirst) { continue }
            if let s = Self.score(query: q, in: entry.lowerName) {
                scored.append((entry, s))
            }
        }
        scored.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            // On a score tie, apps rank above settings.
            if (a.0.kind == .app) != (b.0.kind == .app) { return a.0.kind == .app }
            return a.0.lowerName < b.0.lowerName
        }
        return scored.prefix(limit).map(\.0)
    }

    /// Curated System Settings sections (verified to navigate on macOS 26).
    private static func makeSettings() -> [AppEntry] {
        func s(_ n: String, _ sym: String, _ tint: NSColor, _ id: String) -> AppEntry {
            AppEntry(settings: n, symbol: sym, tint: tint,
                     urlString: "x-apple.systempreferences:\(id)")
        }
        return [
            s("Wi-Fi", "wifi", .systemBlue, "com.apple.preference.network"),
            s("Bluetooth", "antenna.radiowaves.left.and.right", .systemBlue, "com.apple.preferences.Bluetooth"),
            s("Network", "globe", .systemBlue, "com.apple.preference.network"),
            s("VPN", "lock.shield.fill", .systemGray, "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
            s("Sound", "speaker.wave.2.fill", .systemPink, "com.apple.preference.sound"),
            s("Displays", "display", .systemBlue, "com.apple.preference.displays"),
            s("Wallpaper", "photo.fill", .systemTeal, "com.apple.preference.desktopscreeneffect"),
            s("Appearance", "paintbrush.fill", .systemGray, "com.apple.Appearance-Settings.extension"),
            s("Keyboard", "keyboard", .systemGray, "com.apple.preference.keyboard"),
            s("Trackpad", "hand.point.up.left.fill", .systemGray, "com.apple.preference.trackpad"),
            s("Accessibility", "accessibility", .systemBlue, "com.apple.preference.universalaccess"),
            s("Battery", "battery.100", .systemGreen, "com.apple.preference.battery"),
            s("Notifications", "bell.badge.fill", .systemRed, "com.apple.preference.notifications"),
            s("Focus", "moon.fill", .systemIndigo, "com.apple.Focus-Settings.extension"),
            s("Privacy & Security", "lock.fill", .systemBlue, "com.apple.preference.security"),
            s("Lock Screen", "lock.display", .systemGray, "com.apple.Lock-Screen-Settings.extension"),
            s("Date & Time", "clock.fill", .systemGray, "com.apple.preference.datetime"),
            s("Language & Region", "character.bubble.fill", .systemGray, "com.apple.Localization-Settings.extension"),
            s("Software Update", "arrow.down.circle.fill", .systemBlue, "com.apple.preferences.softwareupdate"),
            s("Users & Groups", "person.2.fill", .systemGray, "com.apple.preferences.users"),
            s("Apple Account", "person.crop.circle", .systemGray, "com.apple.preferences.AppleIDPrefPane"),
            s("Desktop & Dock", "dock.rectangle", .systemBlue, "com.apple.preference.dock"),
            s("Control Center", "switch.2", .systemGray, "com.apple.ControlCenter-Settings.extension"),
            s("Spotlight", "magnifyingglass", .systemGray, "com.apple.preference.spotlight"),
            s("Printers & Scanners", "printer.fill", .systemGray, "com.apple.preference.printfax"),
            s("Sharing", "folder.fill", .systemBlue, "com.apple.preferences.sharing"),
            s("Time Machine", "clock.arrow.circlepath", .systemGreen, "com.apple.prefs.backup"),
            s("Screen Time", "hourglass", .systemIndigo, "com.apple.preference.screentime"),
            s("Game Center", "gamecontroller.fill", .systemGreen, "com.apple.Game-Center-Settings.extension"),
            s("Apple Intelligence & Siri", "sparkles", .systemPurple, "com.apple.Siri-Settings.extension"),
        ]
    }

    static func score(query: String, in name: String) -> Int? {
        if name == query { return 10_000 }
        if name.hasPrefix(query) { return 5_000 - name.count }

        let initials = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .compactMap(\.first)
        if initials.count >= query.count {
            let initialsString = String(initials.prefix(query.count)).lowercased()
            if initialsString == query { return 4_000 }
        }

        if let r = name.range(of: query) {
            let pos = name.distance(from: name.startIndex, to: r.lowerBound)
            return 2_000 - pos
        }

        // Subsequence fuzzy with contiguity bonus.
        var qi = query.startIndex
        var lastIdx: String.Index? = nil
        var contigBonus = 0
        var lastMatched: String.Index? = nil
        for idx in name.indices {
            if qi == query.endIndex { break }
            if name[idx] == query[qi] {
                if let last = lastMatched, name.index(after: last) == idx {
                    contigBonus += 10
                }
                lastMatched = idx
                lastIdx = idx
                qi = query.index(after: qi)
            }
        }
        guard qi == query.endIndex, let last = lastIdx else { return nil }
        let span = name.distance(from: name.startIndex, to: last)
        return 500 - span + contigBonus
    }
}
