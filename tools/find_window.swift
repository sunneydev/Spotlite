import Cocoa
import CoreGraphics

let infoOpt = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
guard let info = infoOpt else { print("no windows"); exit(1) }

let candidates = info.filter { ($0[kCGWindowOwnerName as String] as? String) == "Spotlite" }
for c in candidates {
    let b = c[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let w = (b["Width"] as? Double) ?? 0
    let h = (b["Height"] as? Double) ?? 0
    let id = c[kCGWindowNumber as String] as? Int ?? 0
    let layer = c[kCGWindowLayer as String] as? Int ?? 0
    print("id=\(id) layer=\(layer) size=\(w)x\(h)")
}
