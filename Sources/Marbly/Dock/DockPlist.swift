import Foundation

/// One tile from the Dock's `persistent-apps` array.
enum DockEntry: Equatable {
    case app(name: String, url: URL, bundleID: String?)
    case spacer
}

enum DockPlist {
    static var domain: CFString { "com.apple.dock" as CFString }

    /// Path of the Dock's preferences file, watched for changes.
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
    }

    static func readPersistentApps() -> [DockEntry] {
        CFPreferencesAppSynchronize(domain)
        let raw = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]]
        return parse(raw ?? [])
    }

    static func isPinned(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return readPersistentApps().contains {
            if case .app(_, let u, _) = $0 { return u.standardizedFileURL.path == path }
            return false
        }
    }

    /// Adds or removes an app from the Dock's pinned apps, like "Keep in Dock".
    static func setPinned(_ pinned: Bool, url: URL, name: String) {
        CFPreferencesAppSynchronize(domain)
        var tiles = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] ?? []
        let path = url.standardizedFileURL.path
        if pinned {
            guard !isPinned(url) else { return }
            var data: [String: Any] = [
                "file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15],
                "file-label": name,
                "file-type": 41,
            ]
            if let id = Bundle(url: url)?.bundleIdentifier { data["bundle-identifier"] = id }
            tiles.append(["tile-type": "file-tile", "tile-data": data])
        } else {
            tiles.removeAll { tile in
                guard case .app(_, let u, _)? = parse([tile]).first else { return false }
                return u.standardizedFileURL.path == path
            }
        }
        CFPreferencesSetAppValue("persistent-apps" as CFString, tiles as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
        // The Dock only reads its pinned apps at launch.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
    }

    /// Moves a pinned app in the Dock's own list: before `next`, or else after `previous`.
    static func movePinned(_ url: URL, before next: URL?, after previous: URL?) {
        CFPreferencesAppSynchronize(domain)
        var tiles = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] ?? []
        func index(of target: URL?) -> Int? {
            guard let path = target?.standardizedFileURL.path else { return nil }
            return tiles.firstIndex { tile in
                guard case .app(_, let u, _)? = parse([tile]).first else { return false }
                return u.standardizedFileURL.path == path
            }
        }
        guard let from = index(of: url) else { return }
        let tile = tiles.remove(at: from)
        let to = index(of: next) ?? index(of: previous).map { $0 + 1 } ?? from
        tiles.insert(tile, at: min(to, tiles.count))
        CFPreferencesSetAppValue("persistent-apps" as CFString, tiles as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
        // The Dock reads its list at launch.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
    }

    static func parse(_ tiles: [[String: Any]]) -> [DockEntry] {
        tiles.compactMap { tile in
            let type = tile["tile-type"] as? String ?? "file-tile"
            if type.hasSuffix("spacer-tile") { return .spacer }

            guard
                let data = tile["tile-data"] as? [String: Any],
                let file = data["file-data"] as? [String: Any],
                let urlString = file["_CFURLString"] as? String
            else { return nil }

            // Type 15 is a file:// URL string, type 0 is a plain POSIX path.
            let url: URL? = (file["_CFURLStringType"] as? Int) == 0
                ? URL(fileURLWithPath: urlString)
                : URL(string: urlString)
            guard let url else { return nil }

            let name = data["file-label"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            return .app(name: name, url: url, bundleID: data["bundle-identifier"] as? String)
        }
    }

    static var autohide: Bool {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue("autohide" as CFString, domain) as? Bool ?? false
    }

    static var tilesize: Double? {
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue("tilesize" as CFString, domain) as? NSNumber)?.doubleValue
    }

    static var autohideDelay: Double? {
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue("autohide-delay" as CFString, domain) as? NSNumber)?.doubleValue
    }
}
