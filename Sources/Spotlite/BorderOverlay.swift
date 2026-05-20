import AppKit

/// Hairline rounded-rect stroke. Layer-backed so it animates smoothly with
/// the panel's bounds changes. Click-through.
final class BorderOverlay: NSView {
    var cornerRadius: CGFloat = 30 {
        didSet { applyCornerRadius() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        applyCornerRadius()
        applyBorderColor()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func applyCornerRadius() { layer?.cornerRadius = cornerRadius }

    private func applyBorderColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.borderColor = (isDark
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.black.withAlphaComponent(0.10)).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBorderColor()
    }
}
