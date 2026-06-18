import AppKit

final class ResultRow: NSView {
    var onClick: (() -> Void)?

    private let selectionLayer = CALayer()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let typeLabel = NSTextField(labelWithString: "Application")
    private let enterBadge = NSTextField(labelWithString: "↩")
    private var isSelected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        // Raycast-style selection: a soft, neutral, inset highlight — not a
        // bold accent fill. A single CALayer keeps it GPU-cheap.
        selectionLayer.cornerRadius = 10
        selectionLayer.cornerCurve = .continuous
        selectionLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(selectionLayer)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        addSubview(titleLabel)

        // Right-aligned, dimmed type tag (Raycast shows the kind here).
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        typeLabel.textColor = .tertiaryLabelColor
        typeLabel.maximumNumberOfLines = 1
        addSubview(typeLabel)

        // ⏎ keycap, only shown on the selected row.
        enterBadge.translatesAutoresizingMaskIntoConstraints = false
        enterBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        enterBadge.textColor = .secondaryLabelColor
        enterBadge.alignment = .center
        enterBadge.wantsLayer = true
        enterBadge.layer?.cornerRadius = 6
        enterBadge.layer?.cornerCurve = .continuous
        enterBadge.alphaValue = 0
        addSubview(enterBadge)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeLabel.leadingAnchor, constant: -12),

            enterBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            enterBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            enterBadge.widthAnchor.constraint(equalToConstant: 24),
            enterBadge.heightAnchor.constraint(equalToConstant: 22),

            typeLabel.trailingAnchor.constraint(equalTo: enterBadge.leadingAnchor, constant: -10),
            typeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // Inset the selection pill from the row edges, Raycast-style.
        selectionLayer.frame = bounds.insetBy(dx: 8, dy: 3)
    }

    override func mouseUp(with event: NSEvent) { onClick?() }

    func bind(_ entry: AppEntry) {
        iconView.image = entry.icon
        titleLabel.stringValue = entry.name
    }

    func setSelected(_ sel: Bool) {
        guard sel != isSelected else { return }
        isSelected = sel
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.09)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        if sel {
            selectionLayer.backgroundColor = Self.selectionColor(for: effectiveAppearance)
            enterBadge.layer?.backgroundColor = Self.keycapColor(for: effectiveAppearance)
            enterBadge.animator().alphaValue = 1
        } else {
            selectionLayer.backgroundColor = NSColor.clear.cgColor
            enterBadge.animator().alphaValue = 0
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if isSelected {
            selectionLayer.backgroundColor = Self.selectionColor(for: effectiveAppearance)
            enterBadge.layer?.backgroundColor = Self.keycapColor(for: effectiveAppearance)
        }
    }

    private static func isDark(_ a: NSAppearance) -> Bool {
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    private static func selectionColor(for a: NSAppearance) -> CGColor {
        (isDark(a) ? NSColor.white.withAlphaComponent(0.10)
                   : NSColor.black.withAlphaComponent(0.06)).cgColor
    }
    private static func keycapColor(for a: NSAppearance) -> CGColor {
        (isDark(a) ? NSColor.white.withAlphaComponent(0.12)
                   : NSColor.black.withAlphaComponent(0.07)).cgColor
    }
}
