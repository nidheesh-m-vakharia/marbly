import SwiftUI

/// Keycap shapes. Each moves the top face within the cap and changes how deep it's dished.
enum KeycapProfile: String, CaseIterable, Identifiable {
    case cherry, sa, dsa, low
    var id: Self { self }

    var title: String {
        switch self {
        case .cherry: "Cherry"
        case .sa: "SA"
        case .dsa: "DSA"
        case .low: "Low profile"
        }
    }

    var summary: String {
        switch self {
        case .cherry: "Short, sculpted, the classic shape"
        case .sa: "Tall and spherical, vintage feel"
        case .dsa: "Low and uniform, flat-topped"
        case .low: "Thin caps, close to a laptop"
        }
    }

    /// Face inset as fractions of the key size. More bottom inset shows more front wall.
    var inset: (top: Double, side: Double, bottom: Double) {
        switch self {
        case .cherry: (0.045, 0.11, 0.17)
        case .sa: (0.03, 0.13, 0.22)
        case .dsa: (0.07, 0.12, 0.12)
        case .low: (0.04, 0.06, 0.09)
        }
    }

    /// How dark the centre of the concave dish gets.
    var dish: Double {
        switch self {
        case .cherry: 0.12
        case .sa: 0.2
        case .dsa: 0.09
        case .low: 0.04
        }
    }

    /// How far the cap travels when pressed, as a fraction of the key size.
    var travel: Double { self == .low ? 0.035 : 0.06 }
}

/// What fills the space between and around the keys.
enum GapFill: String, CaseIterable, Identifiable {
    case plate, body, color, backlight
    var id: Self { self }

    var title: String {
        switch self {
        case .plate: "Plate"
        case .body: "Body"
        case .color: "Colour"
        case .backlight: "Backlight"
        }
    }

    var summary: String {
        switch self {
        case .plate: "A dark recess, like a bare switch plate."
        case .body: "The case colour, as if the keys sit in the body."
        case .color: "A colour of your choice."
        case .backlight: "Each key glows from beneath in its own colour."
        }
    }
}

/// A single light source over the board.
struct Lighting: Equatable {
    /// Where the light comes from, in degrees. 0 is straight above, negative is left.
    var angle: Double
    /// Strength of the specular highlight on each face, 0…1.
    var intensity: Double
    /// How tight and glossy that highlight is, 0 (matte) … 1 (polished).
    var gloss: Double
    /// Depth of cast shadows, 0…1.
    var shadow: Double

    private var radians: Double { angle * .pi / 180 }

    /// Gradient endpoints running from the lit edge to the far edge.
    var lightStart: UnitPoint { UnitPoint(x: 0.5 + sin(radians) * 0.5, y: 0.5 - cos(radians) * 0.5) }
    var lightEnd: UnitPoint { UnitPoint(x: 0.5 - sin(radians) * 0.5, y: 0.5 + cos(radians) * 0.5) }

    /// Darkening on each side wall: the side facing the light stays brighter.
    var leftWallShade: Double { 0.21 + 0.12 * sin(radians) }
    var rightWallShade: Double { 0.21 - 0.12 * sin(radians) }

    /// Shadows fall away from the light.
    var shadowOffsetX: Double { -sin(radians) * 0.05 * shadow }
}

struct KeyStyle: Equatable {
    var profile: KeycapProfile
    var lighting: Lighting
}

/// Case and plate colours derived from one body colour.
struct CaseFinish {
    let body: [Color]
    let plate: Color
    /// The case colour a step darker, for wells filled with the body.
    let recess: Color
    /// Darker still under a backlight, so the glow reads against it.
    let backlitPlate: Color
    let bevel: Double

    init(_ color: RGB) {
        let (h, s, v) = color.hsv
        body = [RGB(h: h, s: s, v: min(1, v * 1.1)).color, RGB(h: h, s: min(1, s * 1.05), v: v * 0.78).color]
        // The plate sits deep in the case and catches little light.
        plate = RGB(h: h, s: min(1, s * 1.1), v: v * 0.32).color
        recess = RGB(h: h, s: min(1, s * 1.05), v: v * 0.86).color
        backlitPlate = RGB(h: h, s: min(1, s * 1.1), v: v * 0.16).color
        bevel = color.luma > 0.5 ? 0.8 : 0.22
    }
}

extension RGB {
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let n = UInt32(digits, radix: 16) else { return nil }
        self.init(Double((n >> 16) & 0xFF) / 255, Double((n >> 8) & 0xFF) / 255, Double(n & 0xFF) / 255)
    }

    var hex: String {
        let c = [r, g, b].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c[0], c[1], c[2])
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        self.init(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
    }
}

/// One-click looks: a case colour, keycap shape and lighting that work together.
struct Theme: Identifiable {
    let id: String
    let name: String
    let caseColor: RGB
    let profile: KeycapProfile
    let lighting: Lighting

    static let all: [Theme] = [
        Theme(id: "graphite", name: "Graphite", caseColor: RGB(hex: "#2B2D31")!, profile: .cherry,
              lighting: Lighting(angle: -35, intensity: 0.45, gloss: 0.5, shadow: 0.6)),
        Theme(id: "silver", name: "Silver", caseColor: RGB(hex: "#C9CCD1")!, profile: .cherry,
              lighting: Lighting(angle: -35, intensity: 0.5, gloss: 0.55, shadow: 0.5)),
        Theme(id: "milk", name: "Milk", caseColor: RGB(hex: "#EDE6DA")!, profile: .sa,
              lighting: Lighting(angle: -20, intensity: 0.35, gloss: 0.3, shadow: 0.45)),
        Theme(id: "midnight", name: "Midnight", caseColor: RGB(hex: "#1D2433")!, profile: .low,
              lighting: Lighting(angle: -45, intensity: 0.6, gloss: 0.75, shadow: 0.7)),
        Theme(id: "sage", name: "Sage", caseColor: RGB(hex: "#8E9E86")!, profile: .dsa,
              lighting: Lighting(angle: -30, intensity: 0.4, gloss: 0.4, shadow: 0.5)),
        Theme(id: "rose", name: "Rose", caseColor: RGB(hex: "#D8A7A7")!, profile: .sa,
              lighting: Lighting(angle: -25, intensity: 0.4, gloss: 0.35, shadow: 0.5)),
    ]
}
