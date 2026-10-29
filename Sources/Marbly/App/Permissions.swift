import AppKit
import ApplicationServices
import ServiceManagement

/// Tracks the permissions Marbly uses. Changes are picked up from system
/// notifications rather than by polling.
@MainActor
final class Permissions: ObservableObject {
    /// Needed to hear the Dock's Mission Control notifications.
    @Published private(set) var accessibility = AXIsProcessTrusted()
    @Published private(set) var openAtLogin = SMAppService.mainApp.status == .enabled

    /// Login items need a real app bundle; `swift run` can't register one.
    var canOpenAtLogin: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app" }

    private var observers: [NSObjectProtocol] = []

    init() {
        // Posted whenever any app's Accessibility access changes.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            // The trust database updates just after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                MainActor.assumeIsolated { self?.refresh() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
    }

    func refresh() {
        let ax = AXIsProcessTrusted()
        if ax != accessibility { accessibility = ax }
        let login = SMAppService.mainApp.status == .enabled
        if login != openAtLogin { openAtLogin = login }
    }

    /// Shows the system prompt, then opens the Accessibility list in System Settings.
    func requestAccessibility() {
        // The value of kAXTrustedCheckOptionPrompt; the global itself isn't concurrency-safe.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Marbly: login item change failed: \(error.localizedDescription)")
        }
        refresh()
    }
}
