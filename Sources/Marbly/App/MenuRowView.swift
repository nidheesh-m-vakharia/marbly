import AppKit

/// A roomier menu row than AppKit's default: 32 pt tall with 18 pt side padding,
/// a Solar icon, the title, and a muted shortcut on the right. Highlights with a
/// subtle rounded fill rather than the accent colour.
final class MenuRowView: NSView {
    static let width: CGFloat = 264
    static let height: CGFloat = 32
    private static let size = TypeScale.size(-2) // 14.05, the caption size
    private static var font: NSFont { OpenRunde.nsFont(size: size) }
    private static let kern = OpenRunde.tracking(points: size)

    var title: String { didSet { needsDisplay = true } }
    var icon: NSImage? { didSet { needsDisplay = true } }
    private let shortcut: String?
    private let isEnabled: Bool
    /// Set by hover tracking; the menu's own highlight covers keyboard navigation.
    var isHovered = false { didSet { needsDisplay = true } }

    init(title: String, icon: NSImage?, shortcut: String?, enabled: Bool = true) {
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.isEnabled = enabled
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isEnabled && (isHovered || (enclosingMenuItem?.isHighlighted ?? false))
        if highlighted {
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 8, yRadius: 8).fill()
        }

        let primary = isEnabled ? NSColor.labelColor : NSColor.tertiaryLabelColor
        if let icon {
            let rect = NSRect(x: 18, y: (bounds.height - 16) / 2, width: 16, height: 16)
            tinted(icon, primary).draw(in: rect)
        }

        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: primary, .kern: Self.kern]
        let size = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(at: NSPoint(x: 46, y: (bounds.height - size.height) / 2), withAttributes: attrs)

        if let shortcut {
            let muted: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: NSColor.secondaryLabelColor, .kern: Self.kern]
            let s = (shortcut as NSString).size(withAttributes: muted)
            (shortcut as NSString).draw(at: NSPoint(x: bounds.width - 18 - s.width, y: (bounds.height - s.height) / 2),
                                        withAttributes: muted)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Menus are reused; don't reopen with a stale hover.
        isHovered = false
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, let item = enclosingMenuItem, let menu = item.menu else { return }
        menu.cancelTracking()
        // Run the action after the menu has closed.
        if let action = item.action {
            DispatchQueue.main.async { NSApp.sendAction(action, to: item.target, from: item) }
        }
    }

    private func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
