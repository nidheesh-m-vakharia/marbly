import AppKit
import SwiftUI

struct RGB: Equatable, Sendable {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init(h: Double, s: Double, v: Double) {
        let i = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i {
        case 0: self.init(v, t, p)
        case 1: self.init(q, v, p)
        case 2: self.init(p, v, t)
        case 3: self.init(p, q, v)
        case 4: self.init(t, p, v)
        default: self.init(v, p, q)
        }
    }

    var hsv: (h: Double, s: Double, v: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    /// Perceived brightness, 0...1.
    var luma: Double { 0.299 * r + 0.587 * g + 0.114 * b }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

enum IconColor {
    static let hueBins = 24

    /// The colour of the icon's outer edge, so a keycap's walls continue its face.
    /// Falls back to the whole icon when the edge is mostly transparent.
    static func edge(of image: NSImage) -> RGB {
        guard let pixels = sample(image) else { return RGB(0.55, 0.56, 0.6) }
        let ring = edgeRing(pixels, side: sampleSide, width: 3)
        let opaque = stride(from: 3, to: ring.count, by: 4).filter { ring[$0] > 150 }.count
        return opaque >= 24 ? dominant(rgba: ring) : dominant(rgba: pixels)
    }

    static let sampleSide = 24

    /// Pixels within `width` of any border of a square RGBA image.
    static func edgeRing(_ pixels: [UInt8], side: Int, width: Int) -> [UInt8] {
        var out: [UInt8] = []
        for y in 0..<side {
            for x in 0..<side where x < width || y < width || x >= side - width || y >= side - width {
                let i = (y * side + x) * 4
                out.append(contentsOf: pixels[i..<i + 4])
            }
        }
        return out
    }

    /// Samples the icon at 24×24 and returns its dominant colour.
    static func dominant(in image: NSImage) -> RGB {
        sample(image).map(dominant(rgba:)) ?? RGB(0.55, 0.56, 0.6)
    }

    private static func sample(_ image: NSImage) -> [UInt8]? {
        let side = sampleSide
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard
                let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                let ctx = CGContext(
                    data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                    bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? pixels : nil
    }

    /// Picks the most prominent saturated hue family, weighting vivid pixels higher.
    /// Mostly-grey icons (Terminal, Settings) come back as their average grey.
    static func dominant(rgba pixels: [UInt8]) -> RGB {
        var weight = [Double](repeating: 0, count: hueBins)
        var sums = [RGB](repeating: RGB(0, 0, 0), count: hueBins)
        var grey = RGB(0, 0, 0), greyCount = 0.0, opaque = 0.0

        var i = 0
        while i + 3 < pixels.count {
            let a = Double(pixels[i + 3]) / 255
            if a > 0.6 {
                // Un-premultiply.
                let px = RGB(Double(pixels[i]) / 255 / a, Double(pixels[i + 1]) / 255 / a, Double(pixels[i + 2]) / 255 / a)
                let (h, s, v) = px.hsv
                opaque += 1
                if s < 0.2 || v < 0.15 {
                    grey.r += px.r; grey.g += px.g; grey.b += px.b; greyCount += 1
                } else {
                    let w = s * v * (0.5 + 0.5 * s)
                    let bin = min(Int(h * Double(hueBins)), hueBins - 1)
                    weight[bin] += w
                    sums[bin].r += px.r * w; sums[bin].g += px.g * w; sums[bin].b += px.b * w
                }
            }
            i += 4
        }

        guard opaque > 0 else { return RGB(0.55, 0.56, 0.6) }

        let colourful = weight.reduce(0, +)
        if colourful < opaque * 0.06, greyCount > 0 {
            return RGB(grey.r / greyCount, grey.g / greyCount, grey.b / greyCount)
        }

        // Smooth across neighbouring bins so a hue split over a bin edge still wins.
        let n = hueBins
        let best = (0..<n).max { a, b in
            weight[(a + n - 1) % n] + weight[a] + weight[(a + 1) % n]
                < weight[(b + n - 1) % n] + weight[b] + weight[(b + 1) % n]
        }!
        var total = 0.0, acc = RGB(0, 0, 0)
        for j in [(best + n - 1) % n, best, (best + 1) % n] {
            total += weight[j]
            acc.r += sums[j].r; acc.g += sums[j].g; acc.b += sums[j].b
        }
        return RGB(acc.r / total, acc.g / total, acc.b / total)
    }
}

/// Every colour a keycap needs, derived from one base colour.
struct KeycapPalette: Equatable, Sendable {
    let base: RGB
    let faceTop: RGB
    let wallLight: RGB
    let wallDark: RGB
    let legend: RGB

    init(base raw: RGB) {
        let (h, s0, v0) = raw.hsv
        // Keep caps out of pure black / blown-out white so shading stays visible.
        let s = min(s0, 0.85)
        let v = min(max(v0, 0.24), 0.93)
        base = RGB(h: h, s: s, v: v)
        faceTop = RGB(h: h, s: s * 0.88, v: min(1, v * 1.08))
        wallLight = RGB(h: h, s: min(1, s * 1.05), v: v * 0.84)
        wallDark = RGB(h: h, s: min(1, s * 1.1), v: v * 0.55)
        legend = base.luma > 0.62 ? RGB(0.13, 0.13, 0.15) : RGB(0.97, 0.97, 0.98)
    }
}
