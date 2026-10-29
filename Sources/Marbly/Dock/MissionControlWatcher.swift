import AppKit
import ApplicationServices

/// Reports when Mission Control or App Exposé opens and closes, using the Dock's own
/// accessibility notifications, so Marbly can step aside for the real Dock.
/// Event-driven, but needs Accessibility access.
@MainActor
final class MissionControlWatcher {
    var onChange: ((Bool) -> Void)?
    private(set) var isActive = false

    private var observer: AXObserver?
    private var dockLaunch: NSObjectProtocol?

    private static let shown: Set<String> = ["AXExposeShowAllWindows", "AXExposeShowFrontWindows"]
    private static let hidden: Set<String> = ["AXExposeExit", "AXExposeShowDesktop"]

    init() {
        // Marbly restarts the Dock to apply its settings, which drops the observer.
        dockLaunch = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { if self?.observer != nil { self?.start() } }
            }
        }
    }

    func start() {
        stop()
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, name, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<MissionControlWatcher>.fromOpaque(refcon).takeUnretainedValue()
            let event = name as String
            MainActor.assumeIsolated { watcher.handle(event) }
        }
        guard AXObserverCreate(dock.processIdentifier, callback, &created) == .success, let created else { return }

        let element = AXUIElementCreateApplication(dock.processIdentifier)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.shown.union(Self.hidden) {
            AXObserverAddNotification(created, element, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
    }

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        if isActive { handle("AXExposeExit") }
    }

    private func handle(_ event: String) {
        let active = Self.shown.contains(event)
        guard active != isActive else { return }
        isActive = active
        onChange?(active)
    }
}
