import SwiftUI

/// The real switch each switch sound is modelled on: housing materials, stem colour and
/// shape, and the mechanism that makes it linear, tactile, clicky or silent.
struct SwitchDesign {
    enum StemShape { case cross, box }
    enum Mechanism {
        case linear
        /// Legs on the stem ride over a bump in the contact leaf.
        case tactile
        /// A separate jacket around the stem snaps past the leaf (Cherry MX Blue).
        case clickJacket(RGB)
        /// A spring bar across the housing snaps against the box stem (Kailh Box).
        case clickBar(RGB)
        /// Rubber dampeners on the stem soften top-out and bottom-out.
        case silent(RGB)
    }
    /// How the top housing's plastic behaves under light.
    enum Material { case nylon, pom, polycarbonate }

    let name: String
    let top: RGB
    let topMaterial: Material
    let bottom: RGB
    let stem: RGB
    let stemShape: StemShape
    let mechanism: Mechanism
    let goldSpring: Bool

    static func forSwitch(_ type: SwitchType) -> SwitchDesign {
        let black = RGB(hex: "#1D1E21")!
        let clear = RGB(hex: "#E6EDF5")!
        switch type {
        case .brown:
            return .init(name: "Cherry MX Brown", top: black, topMaterial: .nylon, bottom: black,
                         stem: RGB(hex: "#6E4B33")!, stemShape: .cross, mechanism: .tactile, goldSpring: false)
        case .red:
            return .init(name: "Cherry MX Red", top: black, topMaterial: .nylon, bottom: black,
                         stem: RGB(hex: "#C8202F")!, stemShape: .cross, mechanism: .linear, goldSpring: false)
        case .blue:
            return .init(name: "Cherry MX Blue", top: black, topMaterial: .nylon, bottom: black,
                         stem: RGB(hex: "#2A63C4")!, stemShape: .cross,
                         mechanism: .clickJacket(RGB(hex: "#EDEDEA")!), goldSpring: false)
        case .thock:
            let cream = RGB(hex: "#EEE2C6")!
            return .init(name: "NovelKeys Cream", top: cream, topMaterial: .pom, bottom: cream,
                         stem: RGB(hex: "#E7D8B8")!, stemShape: .cross, mechanism: .linear, goldSpring: true)
        case .deep:
            return .init(name: "Cherry MX Black", top: black, topMaterial: .nylon, bottom: black,
                         stem: RGB(hex: "#141416")!, stemShape: .cross, mechanism: .linear, goldSpring: false)
        case .clicky:
            return .init(name: "Kailh Box Navy", top: clear, topMaterial: .polycarbonate, bottom: RGB(hex: "#17181B")!,
                         stem: RGB(hex: "#1F2B57")!, stemShape: .box,
                         mechanism: .clickBar(RGB(hex: "#F2F2EE")!), goldSpring: true)
        case .soft:
            return .init(name: "Cherry MX Silent Red", top: black, topMaterial: .nylon, bottom: black,
                         stem: RGB(hex: "#E57C93")!, stemShape: .cross,
                         mechanism: .silent(RGB(hex: "#8E949B")!), goldSpring: false)
        case .mix:
            return .init(name: "Kailh Box White", top: clear, topMaterial: .polycarbonate, bottom: RGB(hex: "#E9E9E6")!,
                         stem: RGB(hex: "#F5F5F2")!, stemShape: .box,
                         mechanism: .clickBar(RGB(hex: "#FAFAF7")!), goldSpring: true)
        }
    }
}

/// A switch drawn flat from the front, the way it's usually pictured: stem cross on
/// top, the top housing's raised centre and sloped shoulders, the bottom housing, and
/// the two pins. Built from simple shapes in millimetres, roughly to MX proportions
/// (15.6 mm wide housing, 4.1 mm cross), and lit from the board's light.
struct SwitchView: View {
    let design: SwitchDesign
    let unit: CGFloat
    let lighting: Lighting

    var body: some View {
        Canvas { context, size in
            // The switch is about 21 mm tall from cross to pin tips; fit it to the slot.
            let mm = size.height / 22.5
            context.translateBy(x: size.width / 2, y: size.height * 0.04)
            draw(in: &context, mm: mm)
        }
        .frame(width: unit, height: unit)
        .accessibilityLabel("\(design.name) switch")
    }

    // MARK: - Shapes

    private func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, mm: CGFloat) -> CGRect {
        CGRect(x: (x - w / 2) * mm, y: y * mm, width: w * mm, height: h * mm)
    }

    private func rounded(_ r: CGRect, _ radius: CGFloat, mm: CGFloat) -> Path {
        Path(roundedRect: r, cornerRadius: radius * mm, style: .continuous)
    }

    /// A trapezoid from `topWidth` at `y` down to `bottomWidth` at `y + h`.
    private func trapezoid(_ y: CGFloat, _ topWidth: CGFloat, _ bottomWidth: CGFloat, _ h: CGFloat, mm: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -topWidth / 2 * mm, y: y * mm))
        p.addLine(to: CGPoint(x: topWidth / 2 * mm, y: y * mm))
        p.addLine(to: CGPoint(x: bottomWidth / 2 * mm, y: (y + h) * mm))
        p.addLine(to: CGPoint(x: -bottomWidth / 2 * mm, y: (y + h) * mm))
        p.closeSubpath()
        return p
    }

    /// Horizontal shading: brighter on the side the light comes from.
    private func lit(_ c: RGB, _ x0: CGFloat, _ x1: CGFloat, mm: CGFloat, base: Double = 1) -> GraphicsContext.Shading {
        let a = lighting.angle * .pi / 180
        let fromLeft = sin(a) < 0
        let bright = shade(c, base * (1.12 + 0.15 * lighting.intensity))
        let dark = shade(c, base * 0.72)
        return .linearGradient(Gradient(colors: fromLeft ? [bright, dark] : [dark, bright]),
                               startPoint: CGPoint(x: x0 * mm, y: 0), endPoint: CGPoint(x: x1 * mm, y: 0))
    }

    private func shade(_ c: RGB, _ k: Double) -> Color {
        Color(.sRGB, red: min(1, c.r * k), green: min(1, c.g * k), blue: min(1, c.b * k))
    }

    // MARK: - Drawing, back to front

    private func draw(in context: inout GraphicsContext, mm: CGFloat) {
        let clear = design.topMaterial == .polycarbonate
        let topAlpha: Double = clear ? 0.38 : 1
        let sheen: Double = switch design.topMaterial {
        case .nylon: 0.12
        case .pom: 0.28
        case .polycarbonate: 0.5
        }

        // Shadow on the plate beneath.
        var shadow = context
        shadow.addFilter(.blur(radius: 1.2 * mm))
        shadow.fill(Path(ellipseIn: box(0.8, 19.6, 15, 2.2, mm: mm)), with: .color(.black.opacity(0.35 + 0.3 * lighting.shadow)))

        // Pins: a gold switch pin and a copper LED-side pin, below the bottom housing.
        let gold = RGB(hex: "#D9B45B")!
        for x in [-2.6, 3.6] {
            context.fill(rounded(box(x, 16.6, 0.9, 3.6, mm: mm), 0.2, mm: mm), with: lit(gold, x - 0.45, x + 0.45, mm: mm))
        }
        // Plastic locating post in the middle.
        context.fill(rounded(box(0.4, 16.6, 2.4, 2.2, mm: mm), 0.6, mm: mm), with: lit(design.bottom, -0.8, 1.6, mm: mm, base: 0.85))

        // Interior seen through a clear top: stem column, spring, contact leaf.
        if clear {
            context.fill(rounded(box(0, 5.8, 4.4, 6.4, mm: mm), 0.4, mm: mm), with: lit(design.stem, -2.2, 2.2, mm: mm, base: 0.9))
            var spring = Path()
            for i in 0...6 {
                let y = 7.4 + Double(i) * 0.9
                spring.move(to: CGPoint(x: -3.1 * mm, y: y * mm))
                spring.addLine(to: CGPoint(x: 3.1 * mm, y: (y + 0.45) * mm))
            }
            context.stroke(spring, with: .color(design.goldSpring ? gold.color.opacity(0.9) : Color(white: 0.78).opacity(0.9)),
                           lineWidth: 0.35 * mm)
            context.fill(rounded(box(-5.4, 8.2, 0.8, 6.2, mm: mm), 0.2, mm: mm), with: lit(gold, -5.8, -5, mm: mm))
        }

        // Bottom housing: narrower block with side latches.
        context.fill(trapezoid(11.4, 14.2, 13.2, 5.4, mm: mm), with: lit(design.bottom, -7, 7, mm: mm, base: 0.85))
        for side in [-1.0, 1.0] {
            context.fill(rounded(box(side * 7.25, 12.4, 1.1, 2.4, mm: mm), 0.3, mm: mm),
                         with: .color(shade(design.bottom, 0.6)))
        }
        // Seam between the housings.
        context.fill(Path(box(0, 11.2, 15.0, 0.35, mm: mm)), with: .color(.black.opacity(0.45)))

        // Top housing: skirt, sloped shoulders, raised centre.
        var top = context
        top.opacity = topAlpha
        top.fill(rounded(box(0, 8.9, 15.6, 2.5, mm: mm), 0.5, mm: mm), with: lit(design.top, -7.8, 7.8, mm: mm))
        top.fill(trapezoid(5.9, 9.6, 15.6, 3.1, mm: mm), with: lit(design.top, -7.8, 7.8, mm: mm, base: 1.06))
        top.fill(rounded(box(0, 4.6, 9.6, 1.5, mm: mm), 0.4, mm: mm), with: lit(design.top, -4.8, 4.8, mm: mm, base: 1.1))
        // Clip windows on the skirt, the LED slot on the shoulder.
        for x in [-5.0, 5.0] {
            top.fill(rounded(box(x, 9.4, 2.4, 1.3, mm: mm), 0.25, mm: mm), with: .color(.black.opacity(clear ? 0.25 : 0.45)))
        }
        top.fill(rounded(box(4.6, 6.9, 2.6, 0.9, mm: mm), 0.2, mm: mm), with: .color(.black.opacity(clear ? 0.25 : 0.5)))
        // Highlights: the top edges of each step catch the light.
        for (y, w) in [(4.6, 9.6), (5.9, 9.6), (8.9, 15.6)] {
            context.fill(Path(box(0, y, w * 0.92, 0.22, mm: mm)), with: .color(.white.opacity(sheen * (0.5 + lighting.intensity))))
        }

        drawMechanism(in: &context, mm: mm)
        drawStem(in: &context, mm: mm)
    }

    private func drawMechanism(in context: inout GraphicsContext, mm: CGFloat) {
        switch design.mechanism {
        case .clickJacket(let c):
            // The jacket collar around the stem, just above the housing.
            context.fill(rounded(box(0, 3.5, 6.6, 1.4, mm: mm), 0.35, mm: mm), with: lit(c, -3.3, 3.3, mm: mm))
        case .clickBar(let c):
            // The click bar's end, poking out beside the stem.
            context.fill(rounded(box(3.9, 3.9, 1.8, 0.7, mm: mm), 0.3, mm: mm), with: lit(c, 3, 4.8, mm: mm))
        default:
            break
        }
    }

    private func drawStem(in context: inout GraphicsContext, mm: CGFloat) {
        let stem = design.stem
        // Stem body rising out of the housing.
        context.fill(rounded(box(0, 2.6, 5.6, 2.2, mm: mm), 0.35, mm: mm), with: lit(stem, -2.8, 2.8, mm: mm, base: 0.92))

        switch design.mechanism {
        case .tactile:
            // Tactile legs flaring from the stem's sides.
            for side in [-1.0, 1.0] {
                context.fill(rounded(box(side * 3.1, 3.3, 0.7, 1.2, mm: mm), 0.2, mm: mm), with: .color(shade(stem, 0.7)))
            }
        case .silent(let pad):
            for side in [-1.0, 1.0] {
                context.fill(rounded(box(side * 2.2, 4.2, 1.6, 0.5, mm: mm), 0.2, mm: mm), with: .color(pad.color))
            }
        default:
            break
        }

        if design.stemShape == .box {
            // Box stem: a square wall rising around the cross.
            context.fill(rounded(box(0, 0.6, 5.8, 2.4, mm: mm), 0.4, mm: mm), with: lit(stem, -2.9, 2.9, mm: mm, base: 1.02))
            context.fill(rounded(box(0, 0.6, 5.8, 0.7, mm: mm), 0.35, mm: mm), with: .color(shade(stem, 1.25)))
        }

        // The cross: front face of the horizontal arm, the vertical arm rising above it,
        // and their top faces catching the light.
        context.fill(rounded(box(0, 0.9, 4.1, 2.0, mm: mm), 0.2, mm: mm), with: lit(stem, -2.05, 2.05, mm: mm, base: 1.05))
        context.fill(rounded(box(0, 0, 1.31, 2.9, mm: mm), 0.2, mm: mm), with: lit(stem, -0.65, 0.65, mm: mm, base: 1.1))
        context.fill(Path(box(0, 0.9, 4.1, 0.35, mm: mm)), with: .color(shade(stem, 1.35)))
        context.fill(Path(box(0, 0, 1.31, 0.35, mm: mm)), with: .color(shade(stem, 1.4)))
        // Shadow the cross casts onto the stem body.
        context.fill(Path(box(0, 2.6, 4.1, 0.3, mm: mm)), with: .color(.black.opacity(0.35)))
    }
}
