import AppKit

/// Transparent wrapper that hosts the glass view at the top and leaves the
/// rest as click-through dead space. Lets the *window* stay at a constant
/// frame while we animate the glass's height constraint — Auto Layout drives
/// the inner views continuously, so nothing visually lags.
final class GlassWrapperView: NSView {
    weak var glassView: NSView?
    var onClickOutsideGlass: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {} // fully transparent

    override func mouseDown(with event: NSEvent) {
        guard let glass = glassView else { return }
        let pointInWindow = event.locationInWindow
        let glassFrameInWindow = glass.convert(glass.bounds, to: nil)
        if !glassFrameInWindow.contains(pointInWindow) {
            onClickOutsideGlass?()
        } else {
            super.mouseDown(with: event)
        }
    }
}
