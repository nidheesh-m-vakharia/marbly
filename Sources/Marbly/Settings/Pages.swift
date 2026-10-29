import SwiftUI

// MARK: - Appearance

struct AppearancePage: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: DockStore

    /// The first few apps from the real board, so each theme previews with your own keys.
    private var previewApps: [DockApp] {
        Array(store.slots.compactMap { if case .app(let app) = $0.kind { app } else { nil } }.prefix(4))
    }

    private static let swatches = Theme.all.map(\.caseColor) + ["#5B4636", "#2F4F4F", "#E3C770", "#F2F2F2"].compactMap(RGB.init(hex:))

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Theme", detail: "A case colour, keycap shape and lighting that go together.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(Theme.all) { theme in
                        ThemeCard(theme: theme, apps: previewApps, selected: prefs.activeTheme?.id == theme.id) {
                            prefs.apply(theme)
                        }
                    }
                }
                if prefs.activeTheme == nil {
                    Text("Custom: you've changed a theme's colour, keycaps or lighting.")
                        .typeStyle(.caption).foregroundStyle(Radix.slate11)
                }
            }

            SettingsSection("Keyboard body", detail: "The case your keys sit in.") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Case colour").typeStyle(.body).foregroundStyle(Radix.slate12)
                        Text("The plate and bevel are shaded from it.").typeStyle(.caption).foregroundStyle(Radix.slate11)
                    }
                    HStack(spacing: 6) {
                        ForEach(Self.swatches, id: \.hex) { color in
                            Swatch(color: color, selected: prefs.caseColor.hex == color.hex) { prefs.caseColor = color }
                        }
                        ColorPicker("Custom case colour", selection: Binding(
                            get: { prefs.caseColor.color },
                            set: { prefs.caseColor = RGB($0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsSection("Window", detail: "This window only. The board on your screen isn't affected.") {
                SettingRow(label: "Appearance", detail: "Follow your Mac, or always light or dark.") {
                    SegmentedControl(selection: $prefs.appearance, options: WindowAppearance.allCases) { $0.title }
                }
            }
        }
    }
}

/// A theme as a small real board: your first apps as keycaps, in the theme's
/// case colour, keycap shape and lighting. Selection is an indigo fill, never an outline.
/// Corners are concentric: 16 pt outside, 8 pt inset, 8 pt on the preview inside.
private struct ThemeCard: View {
    let theme: Theme
    let apps: [DockApp]
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                MiniBoard(theme: theme, apps: apps)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(Radix.slate3, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name).typeStyle(.body).foregroundStyle(selected ? Radix.indigo11 : Radix.slate12)
                    Text(theme.profile.title).typeStyle(.caption).foregroundStyle(selected ? Radix.indigo11 : Radix.slate11)
                }
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .padding(8)
            .background(selected ? Radix.indigo4 : (hovering ? Radix.slate3 : Radix.slate2),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(Motion.easeOut, value: hovering)
        .animation(Motion.easeOut, value: selected)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The board in miniature, built from the same keycap and case pieces as the real one.
private struct MiniBoard: View {
    let theme: Theme
    let apps: [DockApp]
    private let unit: CGFloat = 30

    var body: some View {
        let finish = CaseFinish(theme.caseColor)
        let style = KeyStyle(profile: theme.profile, lighting: theme.lighting)
        let keyRadius = KeycapView.capRadius(unit: unit, profile: theme.profile)
        let plateRadius = keyRadius + unit * BoardLayout.plate
        let caseRadius = plateRadius + unit * BoardLayout.caseWall
        HStack(spacing: unit * BoardLayout.spacing) {
            ForEach(apps) { app in
                KeycapView(app: app, unit: unit, legend: .icon, style: style, isPressed: false)
            }
        }
        .padding(unit * BoardLayout.plate)
        .background(
            RoundedRectangle(cornerRadius: plateRadius, style: .continuous)
                .fill(finish.plate.shadow(.inner(color: .black.opacity(0.7), radius: 2, y: 1)))
        )
        .padding(unit * BoardLayout.caseWall)
        .background(
            RoundedRectangle(cornerRadius: caseRadius, style: .continuous)
                .fill(LinearGradient(colors: finish.body, startPoint: .top, endPoint: .bottom))
        )
        .drawingGroup()
        .shadow(color: .black.opacity(0.35 * theme.lighting.shadow), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

private struct Swatch: View {
    let color: RGB
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .overlay(Circle().strokeBorder(.black.opacity(0.12)))
                .frame(width: 20, height: 20)
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Radix.indigo9 : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Case colour \(color.hex)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Lighting

struct LightingPage: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SettingsSection("Light source", detail: "One light shines across the whole board.") {
                SliderRow(label: "Direction", detail: "Where the light comes from. Highlights and shadows move with it.", value: $prefs.lighting.angle, range: -90...90) { angle in
                    let degrees = Int(angle.rounded())
                    return "\(Self.direction(angle)) · \(degrees < 0 ? "−" : "")\(abs(degrees))°"
                }
                SliderRow(label: "Highlight", detail: "How bright the reflection on each key is.", value: $prefs.lighting.intensity, range: 0...1, format: Self.percent)
                SliderRow(label: "Gloss", detail: "Matte keys spread the light. Polished keys keep it tight.", value: $prefs.lighting.gloss, range: 0...1) { v in
                    v < 0.34 ? "Matte" : v < 0.67 ? "Satin" : "Polished"
                }
            }
            SettingsSection("Shadows", detail: "Cast by each key and by the board itself.") {
                SliderRow(label: "Depth", detail: "How dark the shadows are and how far they fall.", value: $prefs.lighting.shadow, range: 0...1, format: Self.percent)
            }
            HStack {
                Spacer()
                SecondaryButton("Reset lighting") { prefs.lighting = prefs.activeTheme?.lighting ?? Theme.all[0].lighting }

            }
        }
    }

    static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    static func direction(_ angle: Double) -> String {
        switch angle {
        case ..<(-60): "Left"
        case ..<(-15): "Upper left"
        case ...15: "Above"
        case ...60: "Upper right"
        default: "Right"
        }
    }
}

// MARK: - Keyboard

struct KeyboardPage: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Keycap profile", detail: "The shape of each key and how far it travels when pressed.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(KeycapProfile.allCases) { profile in
                        ChoiceCard(title: profile.title, detail: profile.summary, selected: prefs.profile == profile) {
                            prefs.profile = profile
                        }
                    }
                }
            }
            SettingsSection("Between keys", detail: "What shows in the gaps around each key.") {
                SettingRow(label: "Fill", detail: prefs.gapFill.summary) {
                    SegmentedControl(selection: $prefs.gapFill, options: GapFill.allCases) { $0.title }
                }
                if prefs.gapFill == .color {
                    SettingRow(label: "Colour", detail: "Shaded so the gaps still look recessed.") {
                        ColorPicker("Fill colour", selection: Binding(
                            get: { prefs.gapColor.color },
                            set: { prefs.gapColor = RGB($0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
                if prefs.gapFill == .backlight {
                    SliderRow(label: "Brightness", detail: "How strongly each key's light spills into the gaps.", value: $prefs.backlight, range: 0.1...1,
                              format: LightingPage.percent)
                }
            }

            SettingsSection("Keys", detail: "Size, markings and reflection.") {
                SliderRow(label: "Key size", detail: "Larger keys make a wider board.", value: Binding(
                    get: { prefs.keySize },
                    set: { prefs.keySize = $0.rounded() }
                ), range: 40...88) { "\(Int($0)) pt" }
                SettingRow(label: "Legend", detail: "What's printed on each key.") {
                    SegmentedControl(selection: $prefs.legend, options: LegendStyle.allCases) { $0.title }
                }
                SettingRow(label: "Reflection", detail: "A faded mirror image below the board.") {
                    Toggle("Reflection", isOn: $prefs.showReflection).labelsHidden().toggleStyle(PillSwitchStyle())
                }
            }
        }
    }
}

/// A selectable card. Selection is an indigo fill plus a check, so it never relies on colour alone.
struct ChoiceCard: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).typeStyle(.body)
                    .foregroundStyle(selected ? Radix.indigo11 : Radix.slate12)
                    .padding(.trailing, 28)
                Text(detail).typeStyle(.caption)
                    .foregroundStyle(selected ? Radix.indigo11 : Radix.slate11)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Solar(.checkCircle, size: 20).foregroundStyle(Radix.indigo9)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            // Equal heights across the grid whether the detail takes one line or two.
            .frame(minHeight: 92, alignment: .topLeading)
            .background(selected ? Radix.indigo4 : (hovering ? Radix.slate3 : Radix.slate2),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(Motion.easeOut, value: hovering)
        .animation(Motion.easeOut, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Sound

struct SoundPage: View {
    @ObservedObject var prefs: Preferences
    let sound: SoundEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SettingsSection("Playback", detail: "When sounds play and how loud they are.") {
                SettingRow(label: "Key sounds", detail: "Play a switch sound when you press a key.") {
                    Toggle("Key sounds", isOn: $prefs.soundEnabled).labelsHidden().toggleStyle(PillSwitchStyle())
                }
                SettingRow(label: "Release sounds", detail: "Also play the softer sound as a key comes back up.") {
                    Toggle("Release sounds", isOn: $prefs.releaseSounds).labelsHidden().toggleStyle(PillSwitchStyle())
                }
                SliderRow(label: "Volume", detail: "Relative to your Mac's volume.", value: $prefs.volume, range: 0...1, format: LightingPage.percent)
            }
            .onChange(of: prefs.volume) { preview() }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Switch", detail: "Each one sounds like a different switch. Choose one to hear it.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(SwitchType.allCases) { type in
                        ChoiceCard(title: type.title, detail: type.summary, selected: prefs.switchType == type) {
                            prefs.switchType = type
                            preview()
                        }
                    }
                }
                if !SoundEngine.hasGeneratedSounds(prefs.switchType) {
                    Callout(icon: .dangerTriangle,
                            text: "Using Marbly's built-in sound for \(prefs.switchType.title). Run scripts/generate_sounds.py to render mechsound's version.")
                }
            }
            .disabled(!prefs.soundEnabled)
        }
    }

    private func preview() {
        guard prefs.soundEnabled else { return }
        sound.play(.down, type: prefs.switchType, volume: Float(prefs.volume), pan: 0)
    }
}

// MARK: - Dock

struct DockPage: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var permissions: Permissions
    @Binding var page: SettingsPage

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SettingsSection("Behaviour", detail: "How Marbly takes the Dock's place.") {
                SettingRow(label: "Replace the macOS Dock",
                           detail: "Hides the real Dock while Marbly runs. Your Dock settings come back when you quit.") {
                    Toggle("Replace the macOS Dock", isOn: $prefs.replaceSystemDock)
                        .labelsHidden().toggleStyle(PillSwitchStyle())
                }
                SettingRow(label: "Hide when not in use",
                           detail: "Slides away and returns when the pointer reaches the bottom of the screen.") {
                    Toggle("Hide when not in use", isOn: $prefs.autoHide)
                        .labelsHidden().toggleStyle(PillSwitchStyle())
                }
                SettingRow(label: "Show each window",
                           detail: "An app with several windows gets a key per window, numbered in the corner.") {
                    Toggle("Show each window", isOn: $prefs.showWindows)
                        .labelsHidden().toggleStyle(PillSwitchStyle())
                }
                SettingRow(label: "Cover the Dock in Mission Control",
                           detail: "In Mission Control and Show Desktop, Marbly rises and stays in view over the real Dock.") {
                    Toggle("Cover the Dock in Mission Control", isOn: $prefs.coverMissionControl)
                        .labelsHidden().toggleStyle(PillSwitchStyle())
                }
            }
            if (prefs.coverMissionControl || prefs.showWindows), !permissions.accessibility {
                HStack(spacing: 12) {
                    Callout(icon: .lock, text: "Window keys and covering the Dock in Mission Control need Accessibility access.")
                    SecondaryButton("Review permissions") { page = .permissions }
                }
            }
        }
    }
}

// MARK: - Permissions

struct PermissionsPage: View {
    @ObservedObject var permissions: Permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SettingsSection("Access", detail: "Marbly asks only for what a feature needs.") {
                SettingRow(label: "Accessibility",
                           detail: "Lets Marbly read your apps' window titles and notice Mission Control opening. It reads nothing else.") {
                    HStack(spacing: 10) {
                        StatusBadge(granted: permissions.accessibility, grantedText: "Allowed", missingText: "Not allowed")
                        if !permissions.accessibility {
                            PrimaryButton("Allow access") { permissions.requestAccessibility() }
                        }
                    }
                }
                SettingRow(label: "Open at login", detail: loginDetail) {
                    Toggle("Open at login", isOn: Binding(
                        get: { permissions.openAtLogin },
                        set: { permissions.setOpenAtLogin($0) }
                    ))
                    .labelsHidden().toggleStyle(PillSwitchStyle())
                    .disabled(!permissions.canOpenAtLogin)
                }
            }

            if !permissions.canOpenAtLogin {
                Callout(icon: .code,
                        text: "Marbly is running from Terminal, so macOS asks about your terminal app instead of Marbly. Build the app with scripts/bundle.sh to give Marbly its own entry.")
            }

            Text("Marbly doesn't need Screen Recording, Input Monitoring or Full Disk Access. Sounds play only when you press a key on the board.")
                .typeStyle(.caption)
                .foregroundStyle(Radix.slate11)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loginDetail: String {
        permissions.canOpenAtLogin ? "Start Marbly when you log in." : "Available in the bundled app."
    }
}
