// Renders the Spotlite app icon at 1024×1024 — a glass magnifying lens
// floating on a deep-blue glass tile. Usage: swift tools/make_icon.swift out.png
import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
let gc = NSGraphicsContext(bitmapImageRep: rep)!
gc.shouldAntialias = true
NSGraphicsContext.current = gc

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let full = NSRect(x: 0, y: 0, width: size, height: size)

// ── Tile: continuous-rounded (squircle-ish) clip ────────────────────────────
let tile = NSBezierPath(roundedRect: full, xRadius: 230, yRadius: 230)

NSGraphicsContext.saveGraphicsState()
tile.addClip()

// Base diagonal gradient: vivid azure → deep indigo
NSGradient(colors: [
    srgb(0.28, 0.56, 1.00),
    srgb(0.14, 0.36, 0.93),
    srgb(0.05, 0.15, 0.62),
])!.draw(in: full, angle: 290)

// Radial glow, upper-left, to fake a light source (subtle — keep contrast)
NSGradient(colors: [srgb(0.7, 0.85, 1, 0.30), srgb(1, 1, 1, 0)])!
    .draw(in: full, relativeCenterPosition: NSPoint(x: -0.45, y: 0.6))

// Bottom vignette for depth
NSGradient(colors: [srgb(0, 0, 0.1, 0.45), srgb(0, 0, 0, 0)])!
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size * 0.5), angle: 90)

// Top-edge glass sheen (kept high so it doesn't wash the lens)
NSGradient(colors: [srgb(1, 1, 1, 0.22), srgb(1, 1, 1, 0)])!
    .draw(in: NSRect(x: 0, y: size * 0.72, width: size, height: size * 0.28), angle: 270)

NSGraphicsContext.restoreGraphicsState()

// Inner rim light along the tile edge
tile.lineWidth = 3
srgb(1, 1, 1, 0.35).setStroke()
tile.stroke()

// ── Magnifying glass geometry ───────────────────────────────────────────────
let cx = size * 0.435
let cy = size * 0.560
let R: CGFloat = size * 0.225      // lens centre radius
let t: CGFloat = size * 0.052      // half-thickness of the glass rim

func circle(_ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - radius, y: cy - radius,
                                width: radius * 2, height: radius * 2))
}

// Soft drop shadow cast by the whole glyph
let shadow = NSShadow()
shadow.shadowColor = srgb(0, 0, 0.1, 0.40)
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 40

// ── Handle (draw first, behind the lens) ────────────────────────────────────
let ang: CGFloat = -.pi / 4
let handleStart = NSPoint(x: cx + cos(ang) * (R - 4), y: cy + sin(ang) * (R - 4))
let handleEnd = NSPoint(x: handleStart.x + cos(ang) * size * 0.235,
                        y: handleStart.y + sin(ang) * size * 0.235)
let handle = NSBezierPath()
handle.move(to: handleStart)
handle.line(to: handleEnd)
handle.lineWidth = t * 1.9
handle.lineCapStyle = .round

NSGraphicsContext.saveGraphicsState()
shadow.set()
srgb(0.93, 0.97, 1).setStroke()
handle.stroke()
NSGraphicsContext.restoreGraphicsState()

// Handle highlight streak
let hl = NSBezierPath()
hl.move(to: handleStart)
hl.line(to: handleEnd)
hl.lineWidth = t * 0.55
hl.lineCapStyle = .round
srgb(1, 1, 1, 0.7).setStroke()
hl.stroke()

// ── Lens glass disc (inside the rim) ────────────────────────────────────────
let inner = circle(R - t)
NSGraphicsContext.saveGraphicsState()
inner.addClip()
// faint blue glass tint
srgb(0.55, 0.74, 1.0, 0.16).setFill()
inner.fill()
// big specular highlight, upper-left
NSGradient(colors: [srgb(1, 1, 1, 0.55), srgb(1, 1, 1, 0)])!
    .draw(in: NSRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2),
          relativeCenterPosition: NSPoint(x: -0.45, y: 0.5))
NSGraphicsContext.restoreGraphicsState()

// ── Lens rim: an annulus filled with a tube-like gradient ───────────────────
let rim = NSBezierPath()
rim.append(circle(R + t))
rim.append(circle(R - t))
rim.windingRule = .evenOdd

NSGraphicsContext.saveGraphicsState()
shadow.set()                       // rim also casts the shadow
rim.addClip()
NSGradient(colors: [
    srgb(1, 1, 1, 1.0),            // bright top
    srgb(0.78, 0.88, 1.0, 1.0),
    srgb(0.55, 0.70, 0.95, 1.0),  // shaded bottom
])!.draw(in: NSRect(x: cx - R - t, y: cy - R - t,
                    width: (R + t) * 2, height: (R + t) * 2), angle: 270)
NSGraphicsContext.restoreGraphicsState()

// Crisp rim highlights inner + outer
srgb(1, 1, 1, 0.85).setStroke()
let outerHi = circle(R + t); outerHi.lineWidth = 3; outerHi.stroke()
srgb(0.4, 0.55, 0.85, 0.5).setStroke()
let innerLo = circle(R - t); innerLo.lineWidth = 3; innerLo.stroke()

NSGraphicsContext.restoreGraphicsState()

let url = URL(fileURLWithPath: outPath)
try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!.write(to: url)
print("wrote \(url.path)")
