import Foundation

/// The switch profiles from mechsound, rendered to WAV by scripts/generate_sounds.py.
enum SwitchType: String, CaseIterable, Identifiable, Sendable {
    case brown, red, blue, thock, deep, clicky, soft, mix
    var id: Self { self }

    var title: String {
        switch self {
        case .brown: "Brown"
        case .red: "Red"
        case .blue: "Blue"
        case .thock: "Thock"
        case .deep: "Deep"
        case .clicky: "Clicky"
        case .soft: "Soft"
        case .mix: "Mix"
        }
    }

    var summary: String {
        switch self {
        case .brown: "Tactile, a muted bump and medium clack"
        case .red: "Linear, smooth with a softer clack"
        case .blue: "Clicky on press and release"
        case .thock: "Lubed linear in a dampened case"
        case .deep: "Low, rounded bottom-out"
        case .clicky: "Loud and crisp, like a typewriter"
        case .soft: "Quiet, for long sessions"
        case .mix: "Deep bass with a light click"
        }
    }

    /// Closest built-in voice, used until the WAVs are generated.
    var fallback: SynthVoice {
        switch self {
        case .blue, .clicky: .clicky
        case .brown, .red, .soft: .creamy
        case .thock, .deep, .mix: .thocky
        }
    }
}
