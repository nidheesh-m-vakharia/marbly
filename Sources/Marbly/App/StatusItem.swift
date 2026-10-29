import AppKit
import SwiftUI

/// Marbly's menu bar icon, its menu, and the control window it opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate, NSWindowDelegate {
    private let item: NSStatusItem
    private let prefs: Preferences
    private let store: DockStore
    private let makeSettings: (SettingsNavigation) -> SettingsWindow
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    // Items whose title, state or icon follow a setting; refreshed each time the menu opens.
    private var soundsRow: MenuRowView!
    private var autoHideRow: MenuRowView!

    private static let autosaveName = "MarblyStatusItem"

    init(prefs: Preferences, store: DockStore, makeSettings: @escaping (SettingsNavigation) -> SettingsWindow) {
        self.prefs = prefs
        self.store = store
        self.makeSettings = makeSettings

        // New icons are added furthest left, which on a notched display is often behind
        // the notch. Ask for the right-hand end instead (measured from the right edge).
        // Once the user ⌘-drags the icon, macOS saves their spot under the same key.
        let key = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(0, forKey: key)
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName
        item.behavior = []
        super.init()

        item.button?.image = Self.placeholderLogo
        item.button?.setAccessibilityLabel("Marbly")
        item.button?.target = self
        item.button?.action = #selector(showMenu)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        menu = buildMenu()
    }

    private var menu: NSMenu!

    /// Opens the menu directly under the icon. With custom rows, letting the status item
    /// place the menu sometimes put it at the top-left of the screen.
    @objc private func showMenu() {
        guard let button = item.button else { return }
        let mouse = NSEvent.mouseLocation
        var anchor = NSPoint(x: mouse.x - 12, y: (NSScreen.main?.visibleFrame.maxY ?? mouse.y) - 4)
        // Prefer the icon's own frame, as long as it's actually where the click was.
        if let frame = button.window?.frame, frame.insetBy(dx: -4, dy: -4).contains(mouse) {
            anchor = NSPoint(x: frame.minX, y: frame.minY - 4)
        }
        menuNeedsUpdate(menu)
        button.highlight(true)
        menu.popUp(positioning: nil, at: anchor, in: nil)
        button.highlight(false)
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        // Toggles say what clicking will do, so no checkmark column is needed.
        menu.showsStateColumn = false

        let sounds = action("", .volume, key: "s") { [weak self] in self?.prefs.soundEnabled.toggle() }
        let autoHide = action("", .eyeClosed, key: "h") { [weak self] in self?.prefs.autoHide.toggle() }
        soundsRow = sounds.view as? MenuRowView
        autoHideRow = autoHide.view as? MenuRowView
        menu.addItem(sounds)
        menu.addItem(autoHide)
        menu.addItem(.separator())

        for page in [SettingsPage.appearance, .lighting, .keyboard, .sound, .dock] {
            menu.addItem(action(page.title, page.icon) { [weak self] in self?.openSettings(page) })
        }
        menu.addItem(.separator())

        menu.addItem(action("Refresh apps", .refresh, key: "r") { [weak self] in self?.store.reload() })
        menu.addItem(.separator())

        menu.addItem(action("Settings", .settings, key: ",") { [weak self] in self?.openSettings(nil) })
        menu.addItem(action("Quit Marbly", .logout, key: "q") { NSApp.terminate(nil) })
        menu.addItem(.separator())

        // Version footer, greyed out like a caption.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let footer = NSMenuItem(title: "Marbly \(version)", action: nil, keyEquivalent: "")
        footer.view = MenuRowView(title: footer.title, icon: Self.placeholderLogo, shortcut: nil, enabled: false)
        footer.isEnabled = false
        menu.addItem(footer)
        updateToggles()
        return menu
    }

    private func action(_ title: String, _ icon: SolarIcon, key: String = "", _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title, key: key, handler)
        item.view = MenuRowView(title: title, icon: icon.menuImage(), shortcut: key.isEmpty ? nil : "⌘\(key.uppercased())")
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateToggles()
    }

    private func updateToggles() {
        soundsRow.title = prefs.soundEnabled ? "Mute key sounds" : "Turn on key sounds"
        soundsRow.icon = (prefs.soundEnabled ? SolarIcon.volumeCross : .volume).menuImage()
        autoHideRow.title = prefs.autoHide ? "Always show the board" : "Hide when not in use"
        autoHideRow.icon = (prefs.autoHide ? SolarIcon.eye : .eyeClosed).menuImage()
    }

    // MARK: - Window

    func openSettings(_ page: SettingsPage?) {
        if let page { navigation.page = page }
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            w.title = "Marbly"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.delegate = self
            let host = NSHostingView(rootView: makeSettings(navigation))
            // The window sets the size (900 × 700); the content fills it, title bar included.
            host.sizingOptions = []
            w.contentView = host
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Drop the window and its view tree when closed, so it costs nothing in the background.
    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil
    }

    /// Placeholder mark: a keycap seen from above, its top face set back
    /// from the front edge. Template image, so it follows the menu bar's colour.
    static let placeholderLogo: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            let cap = NSBezierPath(roundedRect: NSRect(x: 2, y: 2.5, width: 14, height: 13), xRadius: 3.5, yRadius: 3.5)
            cap.lineWidth = 1.4
            cap.stroke()
            NSBezierPath(roundedRect: NSRect(x: 5, y: 4.5, width: 8, height: 6.5), xRadius: 2, yRadius: 2).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// Menu item that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler() }
}
