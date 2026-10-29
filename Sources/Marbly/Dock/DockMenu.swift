import AppKit

/// Builds the same right-click menu the macOS Dock shows for an app. It's built when
/// the menu opens, so it reflects current state (pinned, hidden, running).
@MainActor
enum DockMenu {
    static func make(for app: DockApp) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let running = runningApp(at: app.url)
        let isFinder = app.url.standardizedFileURL == DockStore.finderURL.standardizedFileURL

        if isFinder {
            menu.addItem(ClosureMenuItem("New Finder Window") {
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
            })
            menu.addItem(.separator())
        } else {
            let options = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
            options.submenu = optionsMenu(for: app, running: running != nil)
            menu.addItem(options)
            menu.addItem(.separator())
        }

        guard let running else {
            menu.addItem(ClosureMenuItem("Open") { NSWorkspace.shared.openApplication(at: app.url, configuration: .init()) })
            return menu
        }

        menu.addItem(ClosureMenuItem("Show All Windows") { showAllWindows(of: running) })
        if running.isHidden {
            menu.addItem(ClosureMenuItem("Show") { running.unhide() })
        } else {
            menu.addItem(ClosureMenuItem("Hide") { running.hide() })
        }

        if !isFinder {
            menu.addItem(ClosureMenuItem("Quit") { running.terminate() })
            // Holding Option swaps Quit for Force Quit, as in the Dock.
            let force = ClosureMenuItem("Force Quit") { running.forceTerminate() }
            force.isAlternate = true
            force.keyEquivalentModifierMask = .option
            menu.addItem(force)
        }
        return menu
    }

    private static func optionsMenu(for app: DockApp, running: Bool) -> NSMenu {
        let menu = NSMenu()
        let pinned = DockPlist.isPinned(app.url)
        if running {
            let keep = ClosureMenuItem("Keep in Dock") { DockPlist.setPinned(!pinned, url: app.url, name: app.name) }
            keep.state = pinned ? .on : .off
            menu.addItem(keep)
        } else {
            menu.addItem(ClosureMenuItem("Remove from Dock") { DockPlist.setPinned(false, url: app.url, name: app.name) })
        }
        menu.addItem(ClosureMenuItem("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) })
        return menu
    }

    private static func runningApp(at url: URL) -> NSRunningApplication? {
        let path = url.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL.path == path }
    }

    /// App Exposé for one app: bring it forward, then ask Mission Control for its windows.
    private static func showAllWindows(of app: NSRunningApplication) {
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/System/Applications/Mission Control.app/Contents/MacOS/Mission Control")
            p.arguments = ["2"]
            try? p.run()
        }
    }
}
