import SwiftUI

enum LegendStyle: String, CaseIterable, Identifiable {
    case icon, name
    var id: Self { self }
    var title: String { self == .icon ? "Icon" : "Name" }
}

enum WindowAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Every user setting, persisted to UserDefaults as it changes.
@MainActor
final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    // Sound
    @Published var soundEnabled: Bool { didSet { save(soundEnabled, "soundEnabled") } }
    @Published var releaseSounds: Bool { didSet { save(releaseSounds, "releaseSounds") } }
    @Published var volume: Double { didSet { save(volume, "volume") } }
    @Published var switchType: SwitchType { didSet { save(switchType.rawValue, "switchType") } }

    // Keyboard
    @Published var keySize: Double { didSet { save(keySize, "keySize") } }
    @Published var legend: LegendStyle { didSet { save(legend.rawValue, "legend") } }
    @Published var profile: KeycapProfile { didSet { save(profile.rawValue, "profile") } }
    @Published var showReflection: Bool { didSet { save(showReflection, "showReflection") } }

    // Look
    @Published var caseColor: RGB { didSet { save(caseColor.hex, "caseColor") } }
    @Published var lighting: Lighting { didSet { saveLighting() } }
    @Published var gapFill: GapFill { didSet { save(gapFill.rawValue, "gapFill") } }
    @Published var gapColor: RGB { didSet { save(gapColor.hex, "gapColor") } }
    @Published var backlight: Double { didSet { save(backlight, "backlight") } }
    @Published var appearance: WindowAppearance { didSet { save(appearance.rawValue, "appearance") } }

    // Dock
    @Published var replaceSystemDock: Bool { didSet { save(replaceSystemDock, "replaceSystemDock") } }
    @Published var autoHide: Bool { didSet { save(autoHide, "autoHide") } }
    @Published var showWindows: Bool { didSet { save(showWindows, "showWindows") } }
    @Published var coverMissionControl: Bool { didSet { save(coverMissionControl, "coverMissionControl") } }

    var keyStyle: KeyStyle { KeyStyle(profile: profile, lighting: lighting) }

    /// Marbly hides and reveals itself only while it has replaced the Dock. With the real
    /// Dock still active, both would answer the bottom edge and race each other.
    var hidesWhenIdle: Bool { autoHide && replaceSystemDock }

    /// The preset the current settings match, if any.
    var activeTheme: Theme? {
        Theme.all.first { $0.caseColor.hex == caseColor.hex && $0.profile == profile && $0.lighting == lighting }
    }

    func apply(_ theme: Theme) {
        caseColor = theme.caseColor
        profile = theme.profile
        lighting = theme.lighting
    }

    init() {
        let graphite = Theme.all[0]
        defaults.register(defaults: [
            "soundEnabled": true, "releaseSounds": true, "volume": 0.6, "keySize": 56.0,
            "showReflection": true, "replaceSystemDock": true, "coverMissionControl": true, "showWindows": true,
            // Until the user picks otherwise, behave like their Dock does.
            "autoHide": SystemDock.userAutohide,
            "backlight": 0.7,
            "lightAngle": graphite.lighting.angle, "lightIntensity": graphite.lighting.intensity,
            "lightGloss": graphite.lighting.gloss, "lightShadow": graphite.lighting.shadow,
        ])
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        releaseSounds = defaults.bool(forKey: "releaseSounds")
        volume = defaults.double(forKey: "volume")
        switchType = SwitchType(rawValue: defaults.string(forKey: "switchType") ?? "") ?? .brown
        keySize = defaults.double(forKey: "keySize")
        legend = LegendStyle(rawValue: defaults.string(forKey: "legend") ?? "") ?? .icon
        profile = KeycapProfile(rawValue: defaults.string(forKey: "profile") ?? "") ?? .cherry
        showReflection = defaults.bool(forKey: "showReflection")
        caseColor = RGB(hex: defaults.string(forKey: "caseColor") ?? "") ?? graphite.caseColor
        lighting = Lighting(
            angle: defaults.double(forKey: "lightAngle"), intensity: defaults.double(forKey: "lightIntensity"),
            gloss: defaults.double(forKey: "lightGloss"), shadow: defaults.double(forKey: "lightShadow")
        )
        gapFill = GapFill(rawValue: defaults.string(forKey: "gapFill") ?? "") ?? .plate
        gapColor = RGB(hex: defaults.string(forKey: "gapColor") ?? "") ?? RGB(hex: "#3E63DD")!
        backlight = defaults.double(forKey: "backlight")
        appearance = WindowAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        // One-time reset: Replace the macOS Dock is on by default. Turn it back on for
        // anyone who has it saved as off from before this default was settled.
        if defaults.integer(forKey: "prefsVersion") < 2 {
            defaults.removeObject(forKey: "replaceSystemDock")
            defaults.set(2, forKey: "prefsVersion")
        }
        replaceSystemDock = defaults.bool(forKey: "replaceSystemDock")
        autoHide = defaults.bool(forKey: "autoHide")
        coverMissionControl = defaults.bool(forKey: "coverMissionControl")
        showWindows = defaults.bool(forKey: "showWindows")
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private func saveLighting() {
        save(lighting.angle, "lightAngle")
        save(lighting.intensity, "lightIntensity")
        save(lighting.gloss, "lightGloss")
        save(lighting.shadow, "lightShadow")
    }
}
