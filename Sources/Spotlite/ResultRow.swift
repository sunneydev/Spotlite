import AppKit

final class ResultRow: NSView {
    var onClick: (() -> Void)?

    private let selectionLayer = CALayer()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let enterBadge = NSTextField(labelWithString: "")
    private var isSelected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        // Selection background as a single CALayer — cheap, GPU-only animations.
        selectionLayer.cornerRadius = 12
        selectionLayer.cornerCurve = .continuous
        selectionLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(selectionLayer)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        addSubview(titleLabel)

        enterBadge.translatesAutoresizingMaskIntoConstraints = false
        enterBadge.font = .systemFont(ofSize: 11, weight: .semibold)
        enterBadge.textColor = NSColor.white.withAlphaComponent(0.85)
        enterBadge.stringValue = "return"
        enterBadge.alphaValue = 0
        addSubview(enterBadge)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: enterBadge.leadingAnchor, constant: -10),

            enterBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            enterBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // Inset the selection background slightly from row edges.
        let inset: CGFloat = 0
        selectionLayer.frame = bounds.insetBy(dx: inset, dy: 2)
    }

    override func mouseUp(with event: NSEvent) { onClick?() }

    /// Re-bind this recycled row to a new app entry.
    func bind(_ entry: AppEntry) {
        iconView.image = entry.icon
        titleLabel.stringValue = entry.name
    }

    func setSelected(_ sel: Bool) {
        guard sel != isSelected else { return }
        isSelected = sel
        // Short, GPU-driven crossfade. No layout work.
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.09)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        if sel {
            selectionLayer.backgroundColor = NSColor.controlAccentColor
                .withAlphaComponent(0.92).cgColor
            titleLabel.textColor = .white
            enterBadge.animator().alphaValue = 1
        } else {
            selectionLayer.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = .labelColor
            enterBadge.animator().alphaValue = 0
        }
        CATransaction.commit()
    }
}
