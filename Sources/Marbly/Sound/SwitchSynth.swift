import Foundation

/// Fallback voices for when the mechsound WAVs haven't been generated.
enum SynthVoice: Sendable { case thocky, creamy, clicky }

enum Stroke: Sendable { case down, up }

/// Synthesises switch sounds from scratch, so no audio assets ship with the app.
/// A keystroke is a short noise transient, a pitched "body" thump from the case,
/// a higher plastic resonance, and for clicky switches the click-jacket snaps.
enum SwitchSynth {
    static let sampleRate = 44_100.0

    struct Profile {
        var bodyHz: Double, bodyDecay: Double
        var resHz: Double, resDecay: Double, resLevel: Double
        var noiseDecay: Double, noiseLevel: Double
        var clicks: [Double] // onset times in seconds
    }

    static func profile(_ type: SynthVoice, _ stroke: Stroke) -> Profile {
        var p: Profile
        switch type {
        case .thocky:
            p = Profile(bodyHz: 135, bodyDecay: 0.032, resHz: 820, resDecay: 0.011, resLevel: 0.30,
                        noiseDecay: 0.0013, noiseLevel: 0.55, clicks: [])
        case .creamy:
            p = Profile(bodyHz: 205, bodyDecay: 0.022, resHz: 1300, resDecay: 0.008, resLevel: 0.22,
                        noiseDecay: 0.0009, noiseLevel: 0.35, clicks: [])
        case .clicky:
            p = Profile(bodyHz: 250, bodyDecay: 0.016, resHz: 2100, resDecay: 0.006, resLevel: 0.28,
                        noiseDecay: 0.0008, noiseLevel: 0.45, clicks: [0, 0.007])
        }
        if stroke == .up {
            p.bodyHz *= 1.4; p.resHz *= 1.25
            p.bodyDecay *= 0.6; p.resDecay *= 0.7
            p.noiseLevel *= 0.6
            p.clicks = Array(p.clicks.prefix(1))
        }
        return p
    }

    /// - Parameter pitch: small multiplier (≈0.94…1.06) so repeated presses don't sound identical.
    static func render(_ type: SynthVoice, _ stroke: Stroke, pitch: Double, seed: UInt64) -> [Float] {
        let p = profile(type, stroke)
        let count = Int(sampleRate * 0.11)
        var out = [Float](repeating: 0, count: count)
        var rng = SplitMix64(seed: seed)
        var phase = 0.0, lastNoise = 0.0
        let twoPi = 2 * Double.pi

        for i in 0..<count {
            let t = Double(i) / sampleRate

            // High-passed noise burst: the plastic-on-plastic contact.
            let n = rng.nextUnit() * 2 - 1
            let transient = (n - lastNoise) * 0.5 * exp(-t / p.noiseDecay) * p.noiseLevel
            lastNoise = n

            // Body thump with a quick downward pitch glide, like a real bottom-out.
            let f = p.bodyHz * pitch * (1 + 0.6 * exp(-t / 0.004))
            phase += twoPi * f / sampleRate
            let body = sin(phase) * exp(-t / p.bodyDecay)

            let res = sin(twoPi * p.resHz * pitch * t) * exp(-t / p.resDecay) * p.resLevel

            var click = 0.0
            for onset in p.clicks where t >= onset {
                let dt = t - onset
                click += sin(twoPi * 4300 * pitch * dt) * exp(-dt / 0.0012) * 0.7
            }

            let attack = min(1, t / 0.0004)
            out[i] = Float((transient + body + res + click) * attack)
        }

        // Normalise and fade the tail so buffers never end on a pop.
        let peak = out.reduce(0) { max($0, abs($1)) }
        let gain = peak > 0 ? 0.9 / peak * (stroke == .up ? 0.5 : 1) : 0
        let fade = Int(sampleRate * 0.008)
        for i in 0..<count {
            let tail = i >= count - fade ? Float(count - i) / Float(fade) : 1
            out[i] *= Float(gain) * tail
        }
        return out
    }
}

struct SplitMix64: Sendable {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
