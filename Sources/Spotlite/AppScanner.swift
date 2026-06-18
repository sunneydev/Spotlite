import AppKit

final class AppEntry: Hashable {
    let name: String
    let url: URL
    let lowerName: String
    let icon: NSImage

    init(url: URL) {
        self.url = url
        let name = url.deletingPathExtension().lastPathComponent
        self.name = name
        self.lowerName = name.lowercased()
        // Pre-cache the icon — the expensive bit, done once at scan time.
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 40, height: 40)
        self.icon = icon
    }

    static func == (l: AppEntry, r: AppEntry) -> Bool { l.url == r.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

final class AppScanner {
    private(set) var apps: [AppEntry] = []

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
        if q.isEmpty { return Array(apps.prefix(limit)) }

        // Fast first-char filter, then score. Avoids work on the long tail.
        let qFirst = q.first!
        var scored: [(AppEntry, Int)] = []
        scored.reserveCapacity(64)
        for app in apps {
            // Cheap reject: query's first char must appear somewhere.
            if !app.lowerName.contains(qFirst) { continue }
            if let s = Self.score(query: q, in: app.lowerName) {
                scored.append((app, s))
            }
        }
        scored.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0.lowerName < b.0.lowerName
        }
        return scored.prefix(limit).map(\.0)
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
