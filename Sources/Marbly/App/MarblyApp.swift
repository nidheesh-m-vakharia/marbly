import AppKit
import Combine
import SwiftUI

@main
struct MarblyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // The menu bar icon and control window are AppKit (see StatusItemController);
    // SwiftUI just needs a scene to exist.
    var body: some Scene {
        MenuBarExtra("Marbly", isInserted: .constant(false)) { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let prefs = Preferences()
    let store = DockStore()
    let sound = SoundEngine()
    let permissions = Permissions()
    private let missionControl = MissionControlWatcher()
    private var panel: DockPanel?
    private var statusItem: StatusItemController?
    private var signalSources: [DispatchSourceSignal] = []
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon of our own (also covers `swift run`, which has no Info.plist).
        NSApp.setActivationPolicy(.accessory)
        OpenRunde.register()

        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Snapshot.write(to: URL(fileURLWithPath: args[i + 1]), store: store, prefs: prefs, sound: sound,
                           clear: args.contains("--clear"))
            exit(0)
        }
        if let i = args.firstIndex(of: "--snapshot-windows"), i + 1 < args.count {
            Snapshot.writeWindowKeys(to: URL(fileURLWithPath: args[i + 1]), store: store, prefs: prefs)
            exit(0)
        }
        if let i = args.firstIndex(of: "--export-board"), i + 1 < args.count {
            Snapshot.exportBoard(to: URL(fileURLWithPath: args[i + 1]), store: store)
            exit(0)
        }
        if args.contains("--list-keys") {
            for slot in store.slots {
                if case .app(let app) = slot.kind {
                    print(app.name, app.isRunning ? "(running)" : "", app.window.map { "window: \($0.title)" } ?? "")
                } else {
                    print("— spacer")
                }
            }
            exit(0)
        }
        if let i = args.firstIndex(of: "--snapshot-settings"), i + 1 < args.count {
            Snapshot.writeSettings(to: URL(fileURLWithPath: args[i + 1]), delegate: self,
                                   dark: args.contains("--dark"))
            exit(0)
        }

        statusItem = StatusItemController(prefs: prefs, store: store) { [unowned self] navigation in
            SettingsWindow(prefs: prefs, store: store, sound: sound, permissions: permissions, navigation: navigation)
        }

        applySystemDock(prefs.replaceSystemDock)
        prefs.$replaceSystemDock.dropFirst().removeDuplicates()
            .sink { [weak self] on in MainActor.assumeIsolated { self?.applySystemDock(on) } }
            .store(in: &subscriptions)
        restoreDockOnSignals()

        // Window keys need Accessibility to read window titles.
        Publishers.CombineLatest(prefs.$showWindows, permissions.$accessibility)
            .sink { [weak self] show, allowed in
                MainActor.assumeIsolated { self?.store.showsWindows = show && allowed }
            }
            .store(in: &subscriptions)

        let panel = DockPanel(store: store, prefs: prefs, sound: sound)
        panel.show()
        self.panel = panel

        missionControl.onChange = { [weak panel] active in panel?.setMissionControl(active) }
        // Watch Mission Control only while it's wanted and permitted.
        Publishers.CombineLatest(prefs.$coverMissionControl, permissions.$accessibility)
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { [weak self] on in
                MainActor.assumeIsolated {
                    if on { self?.missionControl.start() } else { self?.missionControl.stop() }
                }
            }
            .store(in: &subscriptions)
    }

    func applicationWillTerminate(_ notification: Notification) {
        SystemDock.restore()
    }

    private func applySystemDock(_ replace: Bool) {
        if replace { SystemDock.suppress() } else { SystemDock.restore() }
    }

    /// Ctrl-C in a terminal or `kill` skips applicationWillTerminate, so catch those
    /// too and hand the Dock back before exiting.
    private func restoreDockOnSignals() {
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { SystemDock.restore() }
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

/// Renders the board to a PNG, for checking the look from the command line.
enum Snapshot {
    @MainActor
    /// - Parameter clear: transparent background, for compositing elsewhere (the website).
    static func write(to url: URL, store: DockStore, prefs: Preferences, sound: SoundEngine, clear: Bool = false) {
        let view = KeyboardView(store: store, prefs: prefs, sound: sound)
            .background(clear ? AnyShapeStyle(Color.clear)
                : AnyShapeStyle(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.35)], startPoint: .top, endPoint: .bottom)))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard
            let cg = renderer.cgImage,
            let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { return }
        try? data.write(to: url)
    }

    /// Writes each key's icon (the cropped 144 px raster the board uses) and palette as
    /// JSON, so the website can draw the same keys. Spacers mark group breaks.
    @MainActor
    static func exportBoard(to dir: URL, store: DockStore) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A general set of apps (the default macOS Dock) rather than whoever's
        // Mac this runs on. nil marks a group break.
        let demo: [(String, String, Bool)?] = [
            ("Finder", "/System/Library/CoreServices/Finder.app", true),
            ("Safari", "/Applications/Safari.app", true),
            ("Messages", "/System/Applications/Messages.app", true),
            ("Mail", "/System/Applications/Mail.app", false),
            ("Maps", "/System/Applications/Maps.app", false),
            ("Photos", "/System/Applications/Photos.app", false),
            ("FaceTime", "/System/Applications/FaceTime.app", false),
            ("Calendar", "/System/Applications/Calendar.app", true),
            ("Notes", "/System/Applications/Notes.app", false),
            ("Music", "/System/Applications/Music.app", true),
            nil,
            ("App Store", "/System/Applications/App Store.app", false),
            ("System Settings", "/System/Applications/System Settings.app", false),
        ]
        let slots: [DockSlot] = demo.enumerated().compactMap { i, entry in
            guard let (name, path, running) = entry else { return DockSlot(id: "gap\(i)", kind: .spacer) }
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let app = store.key(name: name, url: URL(fileURLWithPath: path), running: running)
            return DockSlot(id: app.id, kind: .app(app))
        }
        var keys: [[String: Any]] = []
        for slot in slots {
            guard case .app(let app) = slot.kind else {
                keys.append(["spacer": true])
                continue
            }
            let file = app.url.deletingPathExtension().lastPathComponent
                .lowercased().replacingOccurrences(of: " ", with: "-") + ".png"
            if let rep = app.icon.representations.first as? NSBitmapImageRep,
               let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent(file))
            }
            let p = app.palette
            keys.append([
                "name": app.name, "icon": file, "running": app.isRunning,
                "palette": ["base": p.base.hex, "faceTop": p.faceTop.hex, "wallLight": p.wallLight.hex,
                            "wallDark": p.wallDark.hex, "legend": p.legend.hex],
            ])
        }
        if let data = try? JSONSerialization.data(withJSONObject: keys, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("board.json"))
        }
    }

    /// Two keys for one app as if it had two windows, to check the window label.
    @MainActor
    static func writeWindowKeys(to url: URL, store: DockStore, prefs: Preferences) {
        guard case .app(let app)? = store.slots.first?.kind else { return }
        let dummy = AXUIElementCreateApplication(getpid())
        let keys = ["Downloads", "Projects — marbly"].enumerated().map { i, title in
            DockApp(id: title, name: app.name, url: app.url, icon: app.icon, palette: app.palette,
                    isRunning: true, window: AppWindow(element: dummy, title: title), windowNumber: i + 1)
        }
        let view = HStack(spacing: 8) {
            ForEach(keys) { KeycapView(app: $0, unit: 72, legend: .icon, style: prefs.keyStyle, isPressed: false) }
        }
        .padding(24)
        .background(Color(white: 0.1))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let cg = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }

    /// Stacks a few menu rows (the second one hovered) to check spacing.
    @MainActor
    static func writeMenu(to url: URL, dark: Bool) {
        let rows = [
            MenuRowView(title: "Mute key sounds", icon: SolarIcon.volumeCross.menuImage(), shortcut: "⌘S"),
            MenuRowView(title: "Appearance", icon: SolarIcon.palette.menuImage(), shortcut: nil),
            MenuRowView(title: "Settings", icon: SolarIcon.settings.menuImage(), shortcut: "⌘,"),
            MenuRowView(title: "Marbly dev", icon: StatusItemController.placeholderLogo, shortcut: nil, enabled: false),
        ]
        rows[1].isHovered = true
        let h = MenuRowView.height
        let container = NSView(frame: NSRect(x: 0, y: 0, width: MenuRowView.width, height: h * CGFloat(rows.count) + 12))
        container.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        container.wantsLayer = true
        container.layer?.backgroundColor = (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.96, alpha: 1)).cgColor
        for (i, row) in rows.enumerated() {
            row.frame.origin = NSPoint(x: 0, y: container.bounds.height - 6 - h * CGFloat(i + 1))
            container.addSubview(row)
        }
        guard let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else { return }
        container.cacheDisplay(in: container.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// Draws every settings page to <dir>/<page>.png. Uses AppKit's view caching so
    /// native controls render, without needing Screen Recording.
    @MainActor
    static func writeSettings(to dir: URL, delegate: AppDelegate, dark: Bool) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for page in SettingsPage.allCases {
            let root = SettingsWindow(prefs: delegate.prefs, store: delegate.store, sound: delegate.sound,
                                      permissions: delegate.permissions, navigation: SettingsNavigation(page))
            // A plain VStack instead of the live ScrollView, which renders black offscreen.
            let host = NSHostingView(rootView: root.environment(\.snapshotLayout, true))
            // Same window setup as the real one (StatusItemController), so renders match.
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            host.sizingOptions = []
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(page.rawValue).png"))
        }
        writeMenu(to: dir.appendingPathComponent("menu.png"), dark: dark)
    }
}
