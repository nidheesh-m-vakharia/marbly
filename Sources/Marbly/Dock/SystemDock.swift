import Foundation

/// Keeps the macOS Dock out of the way while Marbly runs, and puts it back afterwards.
///
/// The Dock is set to auto-hide with a very long reveal delay, so it never appears.
/// Mission Control still draws it, so its icons are also shrunk to the minimum so
/// Marbly's board can cover it there.
/// The user's original values are saved first and restored on quit. If Marbly crashes,
/// the saved values survive, and the next launch or quit restores them.
@MainActor
enum SystemDock {
    private struct Saved: Codable {
        var autohide: Bool
        var delay: Double?
        var tilesize: Double?
        /// Older saves predate tile size; when false, the current size is still the user's own.
        var capturedTilesize: Bool?
    }

    private static let savedKey = "savedSystemDock"
    private static let suppressedDelay = 1000.0
    private static let suppressedTilesize = 16.0

    private static var saved: Saved? {
        get { UserDefaults.standard.data(forKey: savedKey).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } }
        set { UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: savedKey) }
    }

    /// The user's own auto-hide choice, not the value Marbly forces while running.
    static var userAutohide: Bool { saved?.autohide ?? DockPlist.autohide }

    /// The user's own reveal delay, defaulting to the system's 0.5 s.
    static var userDelay: Double {
        let delay = saved.map { $0.delay } ?? DockPlist.autohideDelay
        return min(delay ?? 0.5, 2)
    }

    static func suppress() {
        if saved == nil {
            saved = Saved(autohide: DockPlist.autohide, delay: DockPlist.autohideDelay,
                          tilesize: DockPlist.tilesize, capturedTilesize: true)
        } else if saved?.capturedTilesize != true {
            saved?.tilesize = DockPlist.tilesize
            saved?.capturedTilesize = true
        }
        guard !DockPlist.autohide || DockPlist.autohideDelay != suppressedDelay
            || DockPlist.tilesize != suppressedTilesize else { return }
        defaults("write", "autohide", "-bool", "true")
        defaults("write", "autohide-delay", "-float", String(suppressedDelay))
        defaults("write", "tilesize", "-float", String(suppressedTilesize))
        restartDock()
    }

    static func restore() {
        guard let original = saved else { return }
        defaults("write", "autohide", "-bool", original.autohide ? "true" : "false")
        if let delay = original.delay {
            defaults("write", "autohide-delay", "-float", String(delay))
        } else {
            defaults("delete", "autohide-delay")
        }
        if original.capturedTilesize == true {
            if let size = original.tilesize {
                defaults("write", "tilesize", "-float", String(size))
            } else {
                defaults("delete", "tilesize")
            }
        }
        saved = nil
        restartDock()
    }

    private static func defaults(_ verb: String, _ args: String...) {
        run("/usr/bin/defaults", [verb, "com.apple.dock"] + args)
    }

    private static func restartDock() {
        run("/usr/bin/killall", ["Dock"])
    }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
