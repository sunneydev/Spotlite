// Renders the Spotlite app icon at 1024×1024.
// Usage:  swift tools/make_icon.swift docs/icon.png
import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("bitmap") }
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
let gc = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gc

// Clip to rounded square (Apple HIG ≈ 22% of side)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = 224
NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()

// Background gradient: vibrant blue, top → bottom
let top   = NSColor(srgbRed: 0.40, green: 0.66, blue: 1.00, alpha: 1.0)
let mid   = NSColor(srgbRed: 0.22, green: 0.48, blue: 0.95, alpha: 1.0)
let bot   = NSColor(srgbRed: 0.10, green: 0.28, blue: 0.78, alpha: 1.0)
NSGradient(colors: [top, mid, bot])!.draw(in: rect, angle: 270)

// Soft top highlight — fakes a glass sheen
NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.22),
    NSColor.white.withAlphaComponent(0.0)
])!.draw(in: NSRect(x: 0, y: size * 0.55, width: size, height: size * 0.45), angle: 270)

// Bottom inner shadow for depth
NSGradient(colors: [
    NSColor.black.withAlphaComponent(0.18),
    NSColor.black.withAlphaComponent(0.0)
])!.draw(in: NSRect(x: 0, y: 0, width: size, height: size * 0.35), angle: 90)

// Magnifying glass — drawn from scratch for crisp output
let cx = size * 0.455
let cy = size * 0.545
let lensR = size * 0.22
let stroke = size * 0.085

NSColor.white.setStroke()

let lens = NSBezierPath(ovalIn: NSRect(
    x: cx - lensR, y: cy - lensR, width: lensR * 2, height: lensR * 2
))
lens.lineWidth = stroke
lens.lineCapStyle = .round
lens.stroke()

let angle: CGFloat = -.pi / 4
let handleStart = NSPoint(x: cx + cos(angle) * lensR, y: cy + sin(angle) * lensR)
let handleLen = size * 0.22
let handleEnd = NSPoint(
    x: handleStart.x + cos(angle) * handleLen,
    y: handleStart.y + sin(angle) * handleLen
)
let handle = NSBezierPath()
handle.move(to: handleStart)
handle.line(to: handleEnd)
handle.lineWidth = stroke
handle.lineCapStyle = .round
handle.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode")
}
let url = URL(fileURLWithPath: outPath)
try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try! data.write(to: url)
print("wrote \(url.path)")
