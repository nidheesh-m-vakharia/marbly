import AppKit
import CoreText

/// Finds Marbly's bundled resources: inside the app after scripts/bundle.sh,
/// or next to the sources under `swift run`.
enum BundledResources {
    static func directory(_ name: String) -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(name),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../Resources/\(name)").standardizedFileURL,
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

/// Open Runde (a rounded Inter, by Laurids Kern; SIL OFL 1.1), registered for this
/// process only so nothing is installed system-wide.
enum OpenRunde {
    static let regular = "OpenRunde-Regular"
    static let medium = "OpenRunde-Medium"
    /// Only for window numbers printed on keys; interface text stops at medium.
    static let semibold = "OpenRunde-Semibold"

    /// Registers the fonts once; safe to call from anywhere that's about to draw text.
    @MainActor static func register() {
        guard !registered, let dir = BundledResources.directory("Fonts") else { return }
        registered = true
        for name in [regular, medium, semibold] {
            let url = dir.appendingPathComponent("\(name).woff2") as CFURL
            CTFontManagerRegisterFontsForURL(url, .process, nil)
        }
    }

    @MainActor private static var registered = false

    /// Inter's Dynamic Metrics tracking, in ems: tighter as text gets larger.
    /// https://rsms.me/inter/dynmetrics/ — a = −0.0223, b = 0.185, c = −0.1745.
    static func tracking(em size: CGFloat) -> CGFloat {
        -0.0223 + 0.185 * exp(-0.1745 * size)
    }

    /// Tracking in points, for `.tracking()` and NSAttributedString's `.kern`.
    static func tracking(points size: CGFloat) -> CGFloat { tracking(em: size) * size }

    /// Line height is 1.4 × size (Inter Dynamic Metrics). The font's own line box is
    /// 1.21 × size, so the gap to add between lines is the difference.
    static func lineSpacing(_ size: CGFloat) -> CGFloat { size * (1.4 - 1.21) }

    static func nsFont(size: CGFloat, medium: Bool = false) -> NSFont {
        NSFont(name: medium ? self.medium : regular, size: size) ?? .systemFont(ofSize: size, weight: medium ? .medium : .regular)
    }
}
