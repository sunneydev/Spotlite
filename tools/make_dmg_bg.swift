// Renders the DMG window background: "drag Spotlite → Applications".
// Usage:  swift tools/make_dmg_bg.swift docs/dmg_bg.png
import AppKit

let w: CGFloat = 600, h: CGFloat = 400
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_bg.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!

// Soft vertical gradient backdrop
NSGradient(colors: [
    NSColor(srgbRed: 0.97, green: 0.98, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.90, green: 0.93, blue: 0.99, alpha: 1),
])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 270)

// Title
let title = "Drag Spotlite to Applications"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
    .foregroundColor: NSColor(srgbRed: 0.12, green: 0.20, blue: 0.40, alpha: 1),
]
let tSize = title.size(withAttributes: titleAttrs)
title.draw(at: NSPoint(x: (w - tSize.width) / 2, y: h - 70), withAttributes: titleAttrs)

// Arrow between the two icons (icons themselves are real Finder icons,
// positioned over this background by AppleScript in make_dmg.sh).
let arrowColor = NSColor(srgbRed: 0.25, green: 0.48, blue: 0.95, alpha: 1)
arrowColor.setStroke()
arrowColor.setFill()
let midY: CGFloat = 200
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: 248, y: midY))
shaft.line(to: NSPoint(x: 352, y: midY))
shaft.lineWidth = 8
shaft.lineCapStyle = .round
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 372, y: midY))
head.line(to: NSPoint(x: 344, y: midY + 18))
head.line(to: NSPoint(x: 344, y: midY - 18))
head.close()
head.fill()

NSGraphicsContext.restoreGraphicsState()

let url = URL(fileURLWithPath: outPath)
try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!.write(to: url)
print("wrote \(url.path)")
