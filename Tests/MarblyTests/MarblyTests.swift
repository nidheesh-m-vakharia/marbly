import AppKit
import Testing
@testable import Marbly

@Suite struct DockPlistTests {
    @Test func parsesAppsAndSpacers() {
        let tiles: [[String: Any]] = [
            ["tile-type": "file-tile", "tile-data": [
                "file-label": "Safari", "bundle-identifier": "com.apple.Safari",
                "file-data": ["_CFURLString": "file:///Applications/Safari.app/", "_CFURLStringType": 15],
            ]],
            ["tile-type": "small-spacer-tile", "tile-data": [:]],
            ["tile-type": "file-tile", "tile-data": [
                "file-data": ["_CFURLString": "/Applications/Notes.app", "_CFURLStringType": 0],
            ]],
            ["tile-type": "file-tile", "tile-data": ["file-label": "Broken"]],
        ]
        let entries = DockPlist.parse(tiles)
        #expect(entries.count == 3)
        #expect(entries[0] == .app(name: "Safari", url: URL(string: "file:///Applications/Safari.app/")!, bundleID: "com.apple.Safari"))
        #expect(entries[1] == .spacer)
        #expect(entries[2] == .app(name: "Notes", url: URL(fileURLWithPath: "/Applications/Notes.app"), bundleID: nil))
    }
}

@Suite struct IconColorTests {
    private func pixels(_ colours: [(UInt8, UInt8, UInt8, Int)]) -> [UInt8] {
        colours.flatMap { r, g, b, n in Array(repeating: [r, g, b, 255], count: n).flatMap { $0 } }
    }

    @Test func picksDominantHueOverGreyBackground() {
        let c = IconColor.dominant(rgba: pixels([(240, 240, 240, 300), (20, 120, 240, 200), (240, 60, 40, 40)]))
        #expect(c.b > c.r && c.b > c.g)
    }

    @Test func greyIconStaysGrey() {
        let c = IconColor.dominant(rgba: pixels([(30, 30, 32, 400), (200, 200, 200, 50)]))
        #expect(c.hsv.s < 0.1)
    }

    @Test func transparentPixelsIgnored() {
        let px = pixels([(255, 0, 0, 100)]) + Array(repeating: 0, count: 4 * 400)
        let c = IconColor.dominant(rgba: px)
        #expect(c.r > 0.8 && c.g < 0.2)
    }

    @Test func paletteKeepsLegendReadable() {
        #expect(KeycapPalette(base: RGB(0.98, 0.95, 0.4)).legend.luma < 0.3)
        #expect(KeycapPalette(base: RGB(0.1, 0.1, 0.4)).legend.luma > 0.9)
    }

    @Test func paletteWallsAreDarkerThanFace() {
        let p = KeycapPalette(base: RGB(0.2, 0.6, 0.9))
        #expect(p.wallDark.luma < p.wallLight.luma)
        #expect(p.wallLight.luma < p.faceTop.luma)
    }
}

@Suite struct SwitchSynthTests {
    @Test(arguments: [SynthVoice.thocky, .creamy, .clicky])
    func rendersBoundedClick(type: SynthVoice) {
        let s = SwitchSynth.render(type, .down, pitch: 1, seed: 42)
        let peak = s.reduce(0) { max($0, abs($1)) }
        #expect(s.count == Int(SwitchSynth.sampleRate * 0.11))
        #expect(peak > 0.85 && peak <= 0.9001)
        #expect(abs(s.last!) < 0.001)
    }

    @Test func upstrokeIsQuieter() {
        let down = SwitchSynth.render(.thocky, .down, pitch: 1, seed: 1).reduce(0) { max($0, abs($1)) }
        let up = SwitchSynth.render(.thocky, .up, pitch: 1, seed: 1).reduce(0) { max($0, abs($1)) }
        #expect(up < down)
    }
}

@Suite struct EdgeAndLayoutTests {
    @Test func edgeRingTakesOnlyBorderPixels() {
        // 6×6 image: border pixels are red, the 2×2 centre is blue.
        var px = [UInt8]()
        for y in 0..<6 { for x in 0..<6 {
            let centre = (2...3).contains(x) && (2...3).contains(y)
            px += centre ? [0, 0, 255, 255] : [255, 0, 0, 255]
        } }
        let ring = IconColor.edgeRing(px, side: 6, width: 2)
        #expect(ring.count == (36 - 4) * 4)
        #expect(stride(from: 0, to: ring.count, by: 4).allSatisfy { ring[$0] == 255 })
    }

    @MainActor @Test func hitTestingFindsKeysAcrossSpacers() {
        let icon = NSImage(size: .init(width: 1, height: 1))
        func slot(_ id: String) -> DockSlot {
            DockSlot(id: id, kind: .app(DockApp(id: id, name: id, url: URL(fileURLWithPath: "/\(id)"), icon: icon,
                                               palette: KeycapPalette(base: RGB(0.5, 0.5, 0.5)), isRunning: false)))
        }
        let slots = [slot("a"), DockSlot(id: "gap", kind: .spacer), slot("b")]
        let layout = BoardLayout(unit: 100)
        let a = layout.keyFrame(0, in: slots)!
        let b = layout.keyFrame(2, in: slots)!
        #expect(BoardLayout.groups(slots).count == 2)
        #expect(layout.app(at: CGPoint(x: b.midX, y: b.midY), in: slots)?.id == "b")
        #expect(layout.app(at: CGPoint(x: (a.maxX + b.minX) / 2, y: b.midY), in: slots) == nil)
        #expect(layout.app(at: CGPoint(x: b.midX, y: 5), in: slots) == nil)
    }
}
