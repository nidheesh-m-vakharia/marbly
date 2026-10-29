import AppKit
import Combine
import SwiftUI

/// Hosting view that takes the first click without activating the app,
/// and reports when the pointer enters or leaves the board.
private final class BoardHostingView<Content: View>: NSHostingView<Content> {
    var onHover: ((Bool) -> Void)?
    /// Returns the Dock menu for the key under a point (top-left coordinates), if any.
    var menuAt: ((CGPoint) -> NSMenu?)?
    var onMenu: ((Bool) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func rightMouseDown(with event: NSEvent) {
        if !showMenu(for: event) { super.rightMouseDown(with: event) }
    }

    override func mouseDown(with event: NSEvent) {
        // Control-click opens the menu too, as in the Dock.
        if event.modifierFlags.contains(.control), showMenu(for: event) { return }
        super.mouseDown(with: event)
    }

    private func showMenu(for event: NSEvent) -> Bool {
        var point = convert(event.locationInWindow, from: nil)
        if !isFlipped { point.y = bounds.height - point.y }
        guard let menu = menuAt?(point) else { return false }
        onMenu?(true)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        onMenu?(false)
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self && $0.userInfo?["marbly"] != nil }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: ["marbly": true]
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea?.userInfo?["marbly"] != nil { onHover?(true) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea?.userInfo?["marbly"] != nil { onHover?(false) }
    }
}

/// An invisible strip along the bottom edge of the screen. It only does work when the
/// pointer enters it, so auto-hide needs no global mouse monitoring.
private final class EdgeView: NSView {
    var onHover: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

/// A borderless, transparent, non-activating panel in the Dock's spot at the bottom of the
/// main screen. With auto-hide on, it sits off-screen (ordered out, so it costs nothing to
/// composite) until the pointer reaches the bottom edge.
@MainActor
final class DockPanel {
    private let panel: NSPanel
    private let hosting: BoardHostingView<KeyboardView>
    private let edge: NSPanel
    private let prefs: Preferences
    private var subscriptions = Set<AnyCancellable>()

    private var isShown = true
    private var menuOpen = false
    private var inMissionControl = false
    private var shrinkWork: DispatchWorkItem?
    private static let dockLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
    /// Mission Control's overlay sits at the Dock's level; this is just above it.
    private static let overlayLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
    private var pending: DispatchWorkItem?
    private var shownFrame = NSRect.zero

    init(store: DockStore, prefs: Preferences, sound: SoundEngine) {
        self.prefs = prefs
        hosting = BoardHostingView(rootView: KeyboardView(store: store, prefs: prefs, sound: sound))
        // Report content size for fittingSize, but leave the window frame to `layout()`.
        hosting.sizingOptions = [.intrinsicContentSize]
        panel = Self.makePanel()
        panel.contentView = hosting

        edge = Self.makePanel()
        // Fully clear windows don't receive mouse events; this is invisible but still hit-testable.
        edge.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        let edgeView = EdgeView()
        edge.contentView = edgeView

        hosting.onHover = { [weak self] inside in self?.pointer(onBoard: inside) }
        hosting.menuAt = { [weak store, weak prefs] point in
            guard let store, let prefs else { return nil }
            return BoardLayout(unit: CGFloat(prefs.keySize)).app(at: point, in: store.slots).map(DockMenu.make)
        }
        hosting.onMenu = { [weak self] open in self?.menu(open: open) }
        edgeView.onHover = { [weak self] inside in self?.pointer(atEdge: inside) }

        // Resize only when the content can actually change size.
        Publishers.Merge(store.objectWillChange, prefs.objectWillChange)
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .sink { [weak self] in MainActor.assumeIsolated { self?.layout() } }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.layout() } }
            .store(in: &subscriptions)
    }

    private static func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = dockLevel
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.becomesKeyOnlyIfNeeded = true
        return p
    }

    func show() {
        layout()
        if prefs.autoHide { conceal(animated: false) } else { reveal(animated: false) }
    }

    /// In Mission Control the system Dock is always drawn. Marbly rises above the overlay
    /// and drops its reflection below the screen edge so the board covers the Dock.
    func setMissionControl(_ active: Bool) {
        inMissionControl = active
        pending?.cancel()
        if active {
            panel.level = Self.overlayLevel
            panel.alphaValue = 1
            panel.setFrame(missionControlFrame, display: true)
            panel.orderFrontRegardless()
        } else {
            panel.level = Self.dockLevel
            if prefs.autoHide, !panel.frame.contains(NSEvent.mouseLocation) {
                isShown = true
                conceal(animated: false)
            } else {
                reveal(animated: false)
            }
        }
    }

    private var missionControlFrame: NSRect {
        let below = BoardLayout.belowBoard(unit: CGFloat(prefs.keySize), reflection: prefs.showReflection)
        return NSRect(x: shownFrame.minX, y: shownFrame.minY - below, width: shownFrame.width, height: shownFrame.height)
    }

    private func layout() {
        // The primary screen is where the system Dock lives.
        guard let screen = NSScreen.screens.first else { return }
        let size = hosting.fittingSize
        let bounds = screen.frame
        // Sit flush with the bottom edge, where the Dock would be. Only respect the
        // visible frame's bottom when the system Dock is still showing.
        let bottom = prefs.replaceSystemDock ? bounds.minY : screen.visibleFrame.minY
        shownFrame = NSRect(x: (bounds.midX - size.width / 2).rounded(), y: bottom, width: size.width, height: size.height)

        edge.setFrame(NSRect(x: shownFrame.minX, y: bounds.minY, width: shownFrame.width, height: 2), display: false)
        if prefs.autoHide { edge.orderFrontRegardless() } else { edge.orderOut(nil) }

        if inMissionControl {
            panel.setFrame(missionControlFrame, display: true)
            return
        }
        if !prefs.autoHide, !isShown { reveal(animated: true) }
        guard isShown, panel.frame != shownFrame else { return }
        // The board animates its own size inside the panel, centred. Growing, the panel
        // makes room straight away; shrinking, it waits for the keys to finish leaving.
        shrinkWork?.cancel()
        if shownFrame.width >= panel.frame.width, shownFrame.height >= panel.frame.height {
            panel.setFrame(shownFrame, display: true)
        } else {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.isShown, !self.inMissionControl else { return }
                    self.panel.setFrame(self.shownFrame, display: true)
                }
            }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }
    }

    private var hiddenFrame: NSRect { shownFrame.offsetBy(dx: 0, dy: -shownFrame.height) }

    // MARK: - Auto-hide

    private func pointer(atEdge inside: Bool) {
        guard prefs.autoHide, !isShown, !inMissionControl else { return }
        if inside {
            schedule(after: SystemDock.userDelay) { $0.reveal(animated: true) }
        } else {
            pending?.cancel()
        }
    }

    private func menu(open: Bool) {
        menuOpen = open
        if open {
            pending?.cancel()
        } else if !panel.frame.contains(NSEvent.mouseLocation) {
            pointer(onBoard: false)
        }
    }

    private func pointer(onBoard inside: Bool) {
        guard prefs.autoHide, isShown, !menuOpen, !inMissionControl else { return }
        if inside {
            pending?.cancel()
        } else {
            schedule(after: 0.4) { $0.conceal(animated: true) }
        }
    }

    private func schedule(after delay: Double, _ action: @escaping (DockPanel) -> Void) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { if let self { action(self) } } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func reveal(animated: Bool) {
        isShown = true
        let fade = reduceMotion
        panel.setFrame(fade || !animated ? shownFrame : hiddenFrame, display: false)
        panel.alphaValue = fade && animated ? 0 : 1
        panel.orderFrontRegardless()
        guard animated else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fade ? 0.18 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            if fade { panel.animator().alphaValue = 1 } else { panel.animator().setFrame(shownFrame, display: true) }
        }
    }

    private func conceal(animated: Bool) {
        isShown = false
        guard animated else { panel.orderOut(nil); return }
        let fade = reduceMotion
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fade ? 0.18 : 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if fade { panel.animator().alphaValue = 0 } else { panel.animator().setFrame(hiddenFrame, display: true) }
        }
        // Order out once off-screen so the window server stops compositing it.
        schedule(after: 0.25) { if !$0.isShown { $0.panel.orderOut(nil) } }
    }
}
