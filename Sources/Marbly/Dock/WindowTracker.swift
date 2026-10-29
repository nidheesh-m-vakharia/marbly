import AppKit
import ApplicationServices

/// One open window of an app, as seen through the Accessibility API.
struct AppWindow: Equatable {
    let element: AXUIElement
    let title: String
    /// Unique for the window's lifetime: its window-server ID where available.
    let id: String

    init(element: AXUIElement, title: String) {
        self.element = element
        self.title = title
        id = Self.windowID(of: element).map { "w\($0)" } ?? "h\(CFHash(element))"
    }

    /// `_AXUIElementGetWindow` is private but long-standing (yabai, AltTab and others use
    /// it). Looked up at runtime so a missing symbol degrades to the hash, not a crash.
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private static let getWindow: GetWindow? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: GetWindow.self)
    }()

    private static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard let getWindow, getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    static func == (a: AppWindow, b: AppWindow) -> Bool {
        CFEqual(a.element, b.element) && a.title == b.title
    }

    /// Brings this exact window to the front.
    func raise(in app: NSRunningApplication) {
        app.activate()
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}

/// Lists each running app's open windows and reports when they change. Event-driven:
/// one AXObserver per app, listening for windows opening, closing, renaming and
/// minimising. Needs Accessibility access; without it, `windows(of:)` is empty.
@MainActor
final class WindowTracker {
    var onChange: (() -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    /// Windows already registered for their own destroyed notification, per app.
    private var watchedWindows: [pid_t: [AXUIElement]] = [:]

    private static let appNotifications = [
        kAXWindowCreatedNotification, kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
    ]

    /// Visible standard windows, in the app's own order. Minimised windows are left out.
    func windows(of app: NSRunningApplication) -> [AppWindow] {
        guard AXIsProcessTrusted() else { return [] }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        // An app that's hung shouldn't stall the board.
        AXUIElementSetMessagingTimeout(element, 0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return [] }

        let windows = list.compactMap { window -> AppWindow? in
            guard string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
                  bool(window, kAXMinimizedAttribute) != true else { return nil }
            return AppWindow(element: window, title: string(window, kAXTitleAttribute) ?? "")
        }
        watch(app.processIdentifier, windows: windows.map(\.element))
        return windows
    }

    /// Drop observers for apps that have quit.
    func forget(except running: Set<pid_t>) {
        for pid in observers.keys where !running.contains(pid) {
            if let observer = observers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
            watchedWindows[pid] = nil
        }
    }

    private func watch(_ pid: pid_t, windows: [AXUIElement]) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if observers[pid] == nil {
            var created: AXObserver?
            let callback: AXObserverCallback = { _, _, _, refcon in
                guard let refcon else { return }
                let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { tracker.onChange?() }
            }
            guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
            let app = AXUIElementCreateApplication(pid)
            for name in Self.appNotifications {
                AXObserverAddNotification(created, app, name as CFString, refcon)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            observers[pid] = created
        }
        guard let observer = observers[pid] else { return }
        // Closing is only reported on the window itself, so register each new one.
        var known = watchedWindows[pid, default: []].filter { w in windows.contains { CFEqual($0, w) } }
        for window in windows where !known.contains(where: { CFEqual($0, window) }) {
            AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, refcon)
            known.append(window)
        }
        watchedWindows[pid] = known
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }
}
