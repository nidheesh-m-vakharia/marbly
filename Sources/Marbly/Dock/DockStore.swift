import AppKit
import Combine

struct DockApp: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
    let palette: KeycapPalette
    var isRunning: Bool
    /// Set when the app has several windows and this key stands for one of them.
    var window: AppWindow? = nil
    /// The window's position among the app's windows, printed on the key (1, 2, …).
    var windowNumber: Int? = nil

    /// What the key's tooltip and label say: the window's title, or the app's name.
    var displayName: String {
        guard let title = window?.title, !title.isEmpty else { return name }
        return title
    }

    static func == (a: DockApp, b: DockApp) -> Bool {
        a.id == b.id && a.name == b.name && a.isRunning == b.isRunning && a.window?.title == b.window?.title
            && a.windowNumber == b.windowNumber
    }
}

struct DockSlot: Identifiable, Equatable {
    enum Kind: Equatable { case app(DockApp), spacer }
    let id: String
    let kind: Kind
}

/// Mirrors the system Dock: pinned apps from its plist, plus running apps that aren't pinned.
/// Event-driven only — no polling timers.
@MainActor
final class DockStore: ObservableObject {
    @Published private(set) var slots: [DockSlot] = []

    /// Icons are rasterised once at a small fixed size; the full .icns reps are dropped.
    private var looks: [String: (icon: NSImage, palette: KeycapPalette)] = [:]
    private var observers: [NSObjectProtocol] = []
    private var plistWatcher: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?
    private let windowTracker = WindowTracker()

    /// One key per window when an app has more than one. Set from preferences.
    var showsWindows = true {
        didSet { if showsWindows != oldValue { reload() } }
    }

    static let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    init() {
        windowTracker.onChange = { [weak self] in self?.scheduleReload() }
        reload()
        let nc = NSWorkspace.shared.notificationCenter
        // Apps report only the windows on the current Space, so refresh on a Space switch too.
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleReload() }
            })
        }
        watchPlist()
    }

    func reload() {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let byPath = Dictionary(running.compactMap { app in app.bundleURL.map { ($0.standardizedFileURL.path, app) } },
                                uniquingKeysWith: { first, _ in first })
        windowTracker.forget(except: Set(running.map(\.processIdentifier)))

        var result: [DockSlot] = []
        var seen = Set<String>()

        func add(name: String, url: URL) {
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return }
            let base = app(name: name, url: url, running: byPath[path] != nil)
            let windows = showsWindows ? byPath[path].map(windowTracker.windows(of:)) ?? [] : []
            guard windows.count > 1 else {
                result.append(DockSlot(id: path, kind: .app(base)))
                return
            }
            // Several windows: a key each, named after its window.
            for (number, window) in windows.enumerated() {
                let id = "\(path)#\(window.id)"
                result.append(DockSlot(id: id, kind: .app(DockApp(
                    id: id, name: base.name, url: url, icon: base.icon, palette: base.palette,
                    isRunning: true, window: window, windowNumber: number + 1
                ))))
            }
        }

        add(name: "Finder", url: Self.finderURL)
        for (i, entry) in DockPlist.readPersistentApps().enumerated() {
            switch entry {
            case .app(let name, let url, _): add(name: name, url: url)
            case .spacer: result.append(DockSlot(id: "spacer-\(i)", kind: .spacer))
            }
        }

        let extras = running.filter { app in
            guard let path = app.bundleURL?.standardizedFileURL.path else { return false }
            return !seen.contains(path)
        }
        if !extras.isEmpty {
            result.append(DockSlot(id: "divider", kind: .spacer))
            for app in extras {
                if let url = app.bundleURL { add(name: app.localizedName ?? url.lastPathComponent, url: url) }
            }
        }

        // Forget looks for apps that are gone so the cache can't grow forever.
        looks = looks.filter { seen.contains($0.key) }
        if result != slots { slots = result }
    }

    func activate(_ app: DockApp) {
        if let window = app.window,
           let running = NSWorkspace.shared.runningApplications.first(where: {
               $0.bundleURL?.standardizedFileURL == app.url.standardizedFileURL
           }) {
            window.raise(in: running)
            return
        }
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }

    /// A key for any app on disk, with the board's cropped icon and palette.
    /// Used by `--export-board` to build the website's demo board.
    func key(name: String, url: URL, running: Bool) -> DockApp {
        app(name: name, url: url, running: running)
    }

    // MARK: - Private

    private func app(name: String, url: URL, running: Bool) -> DockApp {
        let path = url.standardizedFileURL.path
        let look = looks[path] ?? {
            let icon = Self.rasterIcon(for: path)
            let palette = KeycapPalette(base: IconColor.edge(of: icon))
            looks[path] = (icon, palette)
            return (icon, palette)
        }()
        return DockApp(id: path, name: name, url: url, icon: look.icon, palette: look.palette, isRunning: running)
    }

    /// Draws the app icon once into a small bitmap and keeps only that, not the full .icns.
    /// macOS icons sit inside a ~10% transparent margin; it's cropped away so the artwork
    /// can fill a keycap's whole top face. 144 px covers the largest key size at 2x.
    private static func rasterIcon(for path: String) -> NSImage {
        let side = 144
        let margin = 0.098 // 100/1024, the standard icon grid inset
        let source = NSWorkspace.shared.icon(forFile: path)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return source }
        let full = Double(side) / (1 - 2 * margin)
        let inset = (full - Double(side)) / 2
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: -inset, y: -inset, width: full, height: full))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: side / 2, height: side / 2))
        image.addRepresentation(rep)
        return image
    }

    func scheduleReload() {
        // Launch/quit notifications and plist writes arrive in bursts; coalesce them.
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.reload() } }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Kernel-level file watch on the Dock plist. The Dock replaces the file atomically,
    /// so on delete/rename the watch is re-armed against the new file.
    private func watchPlist() {
        plistWatcher?.cancel()
        let fd = open(DockPlist.fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.scheduleReload()
                if let events = source?.data, events.contains(.delete) || events.contains(.rename) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        MainActor.assumeIsolated { self?.watchPlist() }
                    }
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        plistWatcher = source
    }
}
