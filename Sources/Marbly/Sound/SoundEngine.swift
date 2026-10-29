import AVFoundation

/// Plays switch sounds. Only the selected profile's buffers are held (~150 KB),
/// and the audio engine is stopped after a few idle seconds — a running
/// AVAudioEngine keeps the audio thread busy even when silent.
@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SwitchSynth.sampleRate, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var loaded: (type: SwitchType, sounds: [Stroke: [AVAudioPCMBuffer]])?
    private var idleStop: DispatchWorkItem?

    static let soundsDirectory = BundledResources.directory("Sounds")

    init() {
        // Four voices is plenty for one pointer; even fast clicks overlap at most two strokes.
        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
    }

    /// Whether this profile plays mechsound's recordings rather than the fallback synth.
    static func hasGeneratedSounds(_ type: SwitchType) -> Bool {
        guard let dir = soundsDirectory?.appendingPathComponent(type.rawValue) else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("press-0.wav").path)
    }

    /// - Parameter pan: -1 (left) … 1 (right), from the key's position on the board.
    func play(_ stroke: Stroke, type: SwitchType, volume: Float, pan: Float) {
        guard volume > 0, let buffer = buffers(for: type)[stroke]?.randomElement() else { return }
        if !engine.isRunning {
            engine.prepare()
            guard (try? engine.start()) != nil else { return }
        }

        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        node.stop()
        node.volume = volume
        node.pan = max(-1, min(1, pan))
        node.scheduleBuffer(buffer, at: nil)
        node.play()
        scheduleIdleStop()
    }

    private func buffers(for type: SwitchType) -> [Stroke: [AVAudioPCMBuffer]] {
        if let loaded, loaded.type == type { return loaded.sounds }
        let sounds = loadGenerated(type) ?? synthesise(type.fallback)
        // Only the active profile stays in memory.
        loaded = (type, sounds)
        return sounds
    }

    private func loadGenerated(_ type: SwitchType) -> [Stroke: [AVAudioPCMBuffer]]? {
        guard let dir = Self.soundsDirectory?.appendingPathComponent(type.rawValue) else { return nil }
        var out: [Stroke: [AVAudioPCMBuffer]] = [:]
        for (stroke, prefix) in [(Stroke.down, "press"), (.up, "release")] {
            out[stroke] = (0..<8).compactMap { i in
                let url = dir.appendingPathComponent("\(prefix)-\(i).wav")
                guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false),
                      file.processingFormat.sampleRate == format.sampleRate,
                      file.processingFormat.channelCount == 1,
                      let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
                      (try? file.read(into: buf)) != nil
                else { return nil }
                return buf
            }
        }
        return out[.down]?.isEmpty == false ? out : nil
    }

    private func synthesise(_ voice: SynthVoice) -> [Stroke: [AVAudioPCMBuffer]] {
        var out: [Stroke: [AVAudioPCMBuffer]] = [:]
        for stroke in [Stroke.down, .up] {
            out[stroke] = (0..<3).compactMap { v in
                makeBuffer(SwitchSynth.render(voice, stroke, pitch: 0.95 + 0.05 * Double(v), seed: UInt64(v + 1) * 7919))
            }
        }
        return out
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buf.frameLength = buf.frameCapacity
        samples.withUnsafeBufferPointer { src in
            buf.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return buf
    }

    private func scheduleIdleStop() {
        idleStop?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.players.forEach { $0.stop() }
                self.engine.stop()
            }
        }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
