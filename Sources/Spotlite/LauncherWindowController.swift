import AppKit

final class LauncherWindowController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    private let scanner: AppScanner
    private let panel: LauncherPanel
    private let searchField: NSTextField
    private let rowsContainer: NSView
    private let emptyLabel: NSTextField

    /// Always-instantiated row pool — never grows or shrinks.
    private var rowPool: [ResultRow] = []
    private var results: [AppEntry] = []
    private var selected: Int = 0

    private let rowHeight: CGFloat = 56
    private let maxRows: Int = 6
    private let panelWidth: CGFloat = 700
    private let inputHeight: CGFloat = 68
    /// Transparent breathing room around the glass inside the window, so the
    /// drop shadow has space to render instead of being clipped by the window
    /// frame (which made it look like a hard rectangle).
    private let shadowMargin: CGFloat = 48
    private let stackInsetV: CGFloat = 8
    private var collapsedHeight: CGFloat { inputHeight }
    private var expandedHeight: CGFloat {
        inputHeight + 1 /* divider */ + CGFloat(maxRows) * rowHeight + stackInsetV * 2
    }

    /// Top-edge Y of the panel — kept constant across collapse/expand so the
    /// search bar never jumps. Computed at show time from current screen.
    private var anchorTopY: CGFloat = 0
    private var isExpanded = false

    private var dividerView: NSBox!
    private var placeholderLabel: NSTextField!
    private var glassHeightConstraint: NSLayoutConstraint!

    init(scanner: AppScanner) {
        self.scanner = scanner

        let contentRect = NSRect(x: 0, y: 0, width: panelWidth, height: 64)
        let panel = LauncherPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .mainMenu + 2
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hasShadow = false // glass casts its own rounded shadow
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        self.panel = panel

        // Liquid Glass container
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = 30
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.wantsLayer = true

        // Soft rounded drop shadow. NSGlassEffectView's auto-shadow already
        // follows the rounded corners — the bug was the window clipping it into
        // a square. shadowMargin gives it room; these values keep it subtle.
        glass.shadow = NSShadow()
        glass.layer?.shadowColor = NSColor.black.cgColor
        glass.layer?.shadowOpacity = 0.28
        glass.layer?.shadowRadius = 26
        glass.layer?.shadowOffset = CGSize(width: 0, height: -14)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView = container

        // Hairline rim — sits on top of everything, ignores hits
        let rim = BorderOverlay()
        rim.cornerRadius = 30
        rim.translatesAutoresizingMaskIntoConstraints = false


        // ── Input row ─────────────────────────────────────────────────────
        let icon = NSImageView()
        let cfg = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: .secondaryLabelColor))
        icon.image = NSImage(systemSymbolName: "magnifyingglass",
                             accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let inputFont = NSFont.systemFont(ofSize: 30, weight: .light)

        let field = BorderlessTextField()
        field.font = inputFont
        field.placeholderString = nil // we render the placeholder ourselves
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .labelColor
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        self.searchField = field

        // Standalone placeholder — uses the *same* cell class (CenteredTextFieldCell)
        // as the search field, so its internal text layout is byte-identical.
        // That's the only way their baselines truly agree.
        let placeholder = BorderlessTextField()
        placeholder.font = inputFont
        placeholder.textColor = .tertiaryLabelColor
        placeholder.stringValue = "Search"
        placeholder.isEditable = false
        placeholder.isSelectable = false
        placeholder.isBordered = false
        placeholder.isBezeled = false
        placeholder.drawsBackground = false // ← was rendering a solid bg over the glass
        placeholder.focusRingType = .none
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        self.placeholderLabel = placeholder

        let inputRow = NSView()
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputRow.addSubview(icon)
        inputRow.addSubview(field)
        inputRow.addSubview(placeholder)

        let divider = NSBox()
        divider.boxType = .custom
        divider.borderWidth = 0
        divider.fillColor = NSColor.separatorColor.withAlphaComponent(0.25)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.alphaValue = 0
        self.dividerView = divider

        // ── Results container (manual layout — no stack view) ─────────────
        let rowsContainer = NSView()
        rowsContainer.translatesAutoresizingMaskIntoConstraints = false
        rowsContainer.alphaValue = 0
        self.rowsContainer = rowsContainer

        let empty = NSTextField(labelWithString: "No matches")
        empty.font = .systemFont(ofSize: 13, weight: .regular)
        empty.textColor = .tertiaryLabelColor
        empty.translatesAutoresizingMaskIntoConstraints = false
        empty.isHidden = true
        self.emptyLabel = empty

        container.addSubview(inputRow)
        container.addSubview(divider)
        container.addSubview(rowsContainer)
        container.addSubview(rim) // last → drawn on top
        rowsContainer.addSubview(empty)

        // Wrapper holds the glass at the top of a constant-size window. The
        // area below the glass is transparent click-through; clicking it
        // dismisses. This decouples our visible bounds from the window frame
        // so we can animate the glass height with Auto Layout — no NSWindow
        // frame animation, no layout lag.
        let wrapper = GlassWrapperView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.glassView = glass
        panel.contentView = wrapper
        wrapper.addSubview(glass)

        // NSGlassEffectView clips its own contentView to the glass shape — no
        // need to layer-back the container ourselves. Doing so introduces a
        // compositing layer over the glass that subtly tints the input region.
        let glassHeight = glass.heightAnchor.constraint(equalToConstant: inputHeight)
        glassHeight.isActive = true
        self.glassHeightConstraint = glassHeight

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: shadowMargin),
            glass.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: shadowMargin),
            glass.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -shadowMargin),

            container.topAnchor.constraint(equalTo: glass.topAnchor),
            container.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: glass.bottomAnchor),

            inputRow.topAnchor.constraint(equalTo: container.topAnchor),
            inputRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            inputRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            inputRow.heightAnchor.constraint(equalToConstant: inputHeight),

            icon.leadingAnchor.constraint(equalTo: inputRow.leadingAnchor, constant: 24),
            icon.centerYAnchor.constraint(equalTo: inputRow.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: inputRow.trailingAnchor, constant: -24),
            field.centerYAnchor.constraint(equalTo: inputRow.centerYAnchor),

            // Same cell class on both → match leading + centerY (the cell
            // centers its text using its own referenceLineHeight, so centering
            // the frames is enough to align the rendered glyphs).
            placeholder.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            placeholder.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            divider.topAnchor.constraint(equalTo: inputRow.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 1),

            rowsContainer.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: stackInsetV),
            rowsContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowsContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            // Fixed height — does NOT pin to container.bottom. When collapsed,
            // this overflows below the container and is clipped by masksToBounds.
            // That keeps glass's height free to be the inputHeight (68) without
            // Auto Layout silently breaking it to satisfy a bottom constraint.
            rowsContainer.heightAnchor.constraint(equalToConstant: CGFloat(maxRows) * rowHeight),

            empty.centerXAnchor.constraint(equalTo: rowsContainer.centerXAnchor),
            empty.topAnchor.constraint(equalTo: rowsContainer.topAnchor, constant: 18),

            rim.topAnchor.constraint(equalTo: container.topAnchor),
            rim.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rim.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rim.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        super.init()

        // Build the recycled row pool — created once, mutated forever.
        for i in 0..<maxRows {
            let row = ResultRow()
            row.translatesAutoresizingMaskIntoConstraints = false
            rowsContainer.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: rowsContainer.leadingAnchor, constant: 8),
                row.trailingAnchor.constraint(equalTo: rowsContainer.trailingAnchor, constant: -8),
                row.topAnchor.constraint(equalTo: rowsContainer.topAnchor, constant: CGFloat(i) * rowHeight),
                row.heightAnchor.constraint(equalToConstant: rowHeight),
            ])
            row.onClick = { [weak self] in
                guard let self else { return }
                self.selected = i
                self.refreshSelection()
                self.launchSelected()
            }
            // Intentionally no hover-to-select: selection only changes via
            // arrow keys or a deliberate click. Stops the first-row selection
            // from drifting when the panel expands under the cursor.
            rowPool.append(row)
        }

        panel.delegate = self
        field.delegate = self
        wrapper.onClickOutsideGlass = { [weak self] in self?.hide() }

        positionCollapsed()
    }

    // MARK: - Toggle

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        scanner.rescan()
        searchField.stringValue = ""
        placeholderLabel.isHidden = false
        positionCollapsed()
        // Make sure results UI starts hidden.
        rowsContainer.alphaValue = 0
        dividerView.alphaValue = 0
        isExpanded = false
        // Do NOT call NSApp.activate here. Activating the app forces a Space
        // switch when another app is frontmost in fullscreen — macOS would
        // animate out of the fullscreen Space to show ours, so the overlay
        // never lands on top. A .nonactivatingPanel becomes key and takes
        // keyboard input on its own (the app is an accessory), which lets it
        // float over fullscreen apps via .canJoinAllSpaces + .fullScreenAuxiliary.
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Window is sized to EXPANDED dimensions permanently. The glass sits at
    /// the top of the window and we animate its height inside. The window's
    /// top edge is anchored where the expanded panel's top would sit when
    /// centered, so the search bar's screen Y never changes.
    private func positionCollapsed() {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let expandedY = screen.minY + screen.height * 0.5 - expandedHeight / 2
        anchorTopY = expandedY + expandedHeight
        // Window is inflated by shadowMargin on every side; the glass sits inset
        // by that margin so its top-left lands at the intended on-screen anchor.
        let x = screen.midX - panelWidth / 2 - shadowMargin
        panel.setFrame(
            NSRect(x: x,
                   y: anchorTopY - expandedHeight - shadowMargin,
                   width: panelWidth + shadowMargin * 2,
                   height: expandedHeight + shadowMargin * 2),
            display: false
        )
        // Reset glass to collapsed height without animation.
        glassHeightConstraint.constant = collapsedHeight
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) { hide() }

    // MARK: - Text changes

    func controlTextDidChange(_ obj: Notification) {
        let q = searchField.stringValue
        placeholderLabel.isHidden = !q.isEmpty
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            setExpanded(false, animated: true)
        } else {
            applyResults(scanner.search(q))
            setExpanded(true, animated: true)
        }
    }

    // MARK: - Expand / collapse animation

    private func setExpanded(_ expand: Bool, animated: Bool) {
        guard expand != isExpanded else { return }
        isExpanded = expand

        let targetHeight: CGFloat = expand ? expandedHeight : collapsedHeight

        guard animated else {
            glassHeightConstraint.constant = targetHeight
            rowsContainer.alphaValue = expand ? 1 : 0
            dividerView.alphaValue = expand ? 1 : 0
            panel.contentView?.layoutSubtreeIfNeeded()
            return
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.42
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            ctx.allowsImplicitAnimation = true
            glassHeightConstraint.animator().constant = targetHeight
            rowsContainer.animator().alphaValue = expand ? 1 : 0
            dividerView.animator().alphaValue = expand ? 1 : 0
            panel.contentView?.layoutSubtreeIfNeeded()
        }
    }

    // MARK: - Key handling

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)):
            hide(); return true
        case #selector(NSResponder.insertNewline(_:)),
             #selector(NSResponder.insertLineBreak(_:)):
            launchSelected(); return true
        case #selector(NSResponder.moveDown(_:)),
             #selector(NSResponder.insertTab(_:)):
            move(by: +1); return true
        case #selector(NSResponder.moveUp(_:)),
             #selector(NSResponder.insertBacktab(_:)):
            move(by: -1); return true
        default:
            return false
        }
    }

    private func move(by delta: Int) {
        guard !results.isEmpty else { return }
        selected = (selected + delta + results.count) % results.count
        refreshSelection()
    }

    private func launchSelected() {
        guard results.indices.contains(selected) else { return }
        let entry = results[selected]
        switch entry.kind {
        case .app:
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: entry.url, configuration: cfg) { _, _ in }
        case .settings:
            NSWorkspace.shared.open(entry.url)
        }
        hide()
    }

    // MARK: - Result rendering (O(maxRows), no view churn)

    private func applyResults(_ list: [AppEntry]) {
        results = list
        selected = 0
        // Disable implicit animations during content swap — instant feel.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, row) in rowPool.enumerated() {
            if i < list.count {
                row.bind(list[i])
                row.isHidden = false
            } else {
                row.isHidden = true
            }
        }
        let hasQuery = !searchField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
        emptyLabel.isHidden = !(hasQuery && list.isEmpty)
        refreshSelection()
        CATransaction.commit()
    }

    private func refreshSelection() {
        for (i, row) in rowPool.enumerated() {
            row.setSelected(i == selected && i < results.count)
        }
    }
}

final class BorderlessTextField: NSTextField {
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        window?.makeFirstResponder(self)
    }
}
