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

/// A switch seen from above, as it sits in the plate with its keycap lifted off.
///
/// Drawn at true scale in millimetres: a key unit is 19.05 mm pitch with an 18 mm cap,
/// the top housing is about 15.6 mm square, and the Cherry MX cross is 4.1 mm wide
/// with 1.17 mm horizontal and 1.31 mm vertical arms. One Canvas, one draw pass.
struct SwitchView: View {
    let design: SwitchDesign
    let unit: CGFloat
    let lighting: Lighting

    var body: some View {
        Canvas { context, size in
            let mm = size.width / 18
            context.translateBy(x: size.width / 2, y: size.height / 2)
            draw(in: &context, mm: mm)
        }
        .frame(width: unit, height: unit)
        .accessibilityLabel("\(design.name) switch")
    }

    // MARK: - Drawing

    private func rect(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, mm: CGFloat) -> CGRect {
        CGRect(x: (cx - w / 2) * mm, y: (cy - h / 2) * mm, width: w * mm, height: h * mm)
    }

    private func rounded(_ r: CGRect, _ radius: CGFloat, mm: CGFloat) -> Path {
        Path(roundedRect: r, cornerRadius: radius * mm, style: .continuous)
    }

    /// Light direction in screen space (x right, y down), from the board's lighting.
    private var light: CGVector {
        let a = lighting.angle * .pi / 180
        return CGVector(dx: sin(a), dy: -cos(a))
    }

    private func draw(in context: inout GraphicsContext, mm: CGFloat) {
        let top = design.top, bottom = design.bottom
        let housing = rect(0, 0, 15.6, 15.6, mm: mm)
        let housingShape = rounded(housing, 1.3, mm: mm)
        let shadowAway = CGSize(width: -light.dx * 0.6 * mm, height: -light.dy * 0.6 * mm + 0.4 * mm)

        // Contact shadow: the housing sitting proud of the plate.
        var shadow = context
        shadow.addFilter(.blur(radius: 0.9 * mm))
        shadow.fill(rounded(housing.offsetBy(dx: shadowAway.width, dy: shadowAway.height), 1.6, mm: mm),
                    with: .color(.black.opacity(0.55 * lighting.shadow + 0.15)))

        // Bottom housing peeking out around the top housing's skirt.
        context.fill(rounded(rect(0, 0.25, 15.9, 15.7, mm: mm), 1.4, mm: mm), with: .color(shade(bottom, 0.7)))

        let clear = design.topMaterial == .polycarbonate
        if clear {
            // Through a clear top: the bottom housing floor, the gold contact leaf, the spring.
            context.fill(housingShape, with: .color(shade(bottom, 0.85)))
            context.fill(rounded(rect(-5.3, -0.4, 1.4, 6.2, mm: mm), 0.3, mm: mm),
                         with: .linearGradient(Gradient(colors: [RGB(hex: "#F2D27A")!.color, RGB(hex: "#B8892E")!.color]),
                                               startPoint: CGPoint(x: -6 * mm, y: 0), endPoint: CGPoint(x: -4.6 * mm, y: 0)))
            for r in [2.95, 2.55] {
                context.stroke(Path(ellipseIn: rect(0, 0.2, r * 2, r * 2, mm: mm)),
                               with: .color(design.goldSpring ? RGB(hex: "#D7B45A")!.color.opacity(0.85) : Color(white: 0.75).opacity(0.8)),
                               lineWidth: 0.32 * mm)
            }
        }

        // Top housing: material decides how much it tints, shines and shows through.
        let (fillOpacity, sheen, rim) = materialLook(design.topMaterial)
        context.fill(housingShape, with: .linearGradient(
            Gradient(colors: [shade(top, 1.12).opacity(fillOpacity), shade(top, 0.86).opacity(fillOpacity)]),
            startPoint: CGPoint(x: light.dx * 7.8 * mm, y: light.dy * 7.8 * mm),
            endPoint: CGPoint(x: -light.dx * 7.8 * mm, y: -light.dy * 7.8 * mm)))
        // Specular sheen across the housing, toward the light.
        context.fill(housingShape, with: .radialGradient(
            Gradient(colors: [.white.opacity(sheen * lighting.intensity * (0.6 + 0.6 * lighting.gloss)), .clear]),
            center: CGPoint(x: light.dx * 4.5 * mm, y: light.dy * 4.5 * mm), startRadius: 0, endRadius: 9 * mm))
        // Bevel: lit edge bright, far edge dark.
        context.stroke(rounded(housing.insetBy(dx: 0.25 * mm, dy: 0.25 * mm), 1.15, mm: mm),
                       with: .linearGradient(Gradient(colors: [.white.opacity(rim), .clear, .black.opacity(0.45)]),
                                             startPoint: CGPoint(x: light.dx * 7.8 * mm, y: light.dy * 7.8 * mm),
                                             endPoint: CGPoint(x: -light.dx * 7.8 * mm, y: -light.dy * 7.8 * mm)),
                       lineWidth: 0.5 * mm)

        // Moulded details on the top housing.
        let detail = Color.black.opacity(clear ? 0.25 : 0.38)
        for side in [-1.0, 1.0] {
            for y in [-4.3, 4.3] {
                // Clip windows where the top housing latches onto the bottom.
                context.fill(rounded(rect(side * 7.15, y, 0.9, 2.8, mm: mm), 0.25, mm: mm), with: .color(detail))
            }
            // Ejector pin marks.
            context.stroke(Path(ellipseIn: rect(side * 4.9, 5.6, 1.0, 1.0, mm: mm)), with: .color(detail), lineWidth: 0.18 * mm)
        }
        // LED window, at the north edge.
        context.fill(rounded(rect(0, -5.6, 4.3, 1.7, mm: mm), 0.3, mm: mm), with: .color(.black.opacity(clear ? 0.3 : 0.55)))
        context.stroke(rounded(rect(0, -5.6, 4.3, 1.7, mm: mm), 0.3, mm: mm),
                       with: .color(.white.opacity(rim * 0.5)), lineWidth: 0.15 * mm)

        // Stem opening: a shaded well the stem rises through.
        let opening = rounded(rect(0, 0, 7.4, 6.2, mm: mm), 0.6, mm: mm)
        context.fill(opening, with: .color(.black.opacity(0.65)))
        context.stroke(opening, with: .linearGradient(Gradient(colors: [.black.opacity(0.6), .white.opacity(rim * 0.7)]),
                                                      startPoint: CGPoint(x: light.dx * 3.5 * mm, y: light.dy * 3.5 * mm),
                                                      endPoint: CGPoint(x: -light.dx * 3.5 * mm, y: -light.dy * 3.5 * mm)),
                       lineWidth: 0.25 * mm)

        drawMechanism(in: &context, mm: mm)
        drawStem(in: &context, mm: mm)
    }

    private func drawMechanism(in context: inout GraphicsContext, mm: CGFloat) {
        switch design.mechanism {
        case .clickJacket(let c):
            // The jacket rides around the stem, a lighter collar inside the opening.
            context.fill(rounded(rect(0, 0, 6.6, 5.4, mm: mm), 0.5, mm: mm), with: .color(shade(c, 0.95)))
        case .clickBar(let c):
            // The click bar spans the south side of the opening.
            context.fill(rounded(rect(0, 2.5, 6.2, 0.7, mm: mm), 0.35, mm: mm),
                         with: .linearGradient(Gradient(colors: [shade(c, 1.05), shade(c, 0.75)]),
                                               startPoint: CGPoint(x: 0, y: 2.15 * mm), endPoint: CGPoint(x: 0, y: 2.85 * mm)))
        case .linear, .tactile, .silent:
            break
        }
    }

    private func drawStem(in context: inout GraphicsContext, mm: CGFloat) {
        let stem = design.stem
        let up = CGPoint(x: light.dx * 2.5 * mm, y: light.dy * 2.5 * mm)
        let down = CGPoint(x: -light.dx * 2.5 * mm, y: -light.dy * 2.5 * mm)
        let stemFill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [shade(stem, 1.18), shade(stem, 0.82)]), startPoint: up, endPoint: down)

        // Stem body inside the opening.
        let body = rect(0, 0, 5.6, 4.4, mm: mm)
        context.fill(rounded(body, 0.5, mm: mm), with: stemFill)

        switch design.mechanism {
        case .tactile:
            // Tactile legs on the stem's sides.
            for side in [-1.0, 1.0] {
                context.fill(rounded(rect(side * 3.05, -1.1, 0.6, 1.1, mm: mm), 0.2, mm: mm), with: .color(shade(stem, 0.7)))
            }
        case .silent(let pad):
            // Dampener pads front and back.
            for y in [-2.45, 2.45] {
                context.fill(rounded(rect(0, y, 3.2, 0.55, mm: mm), 0.27, mm: mm), with: .color(pad.color))
            }
        default:
            break
        }

        // The cross protrudes about 3.6 mm above the housing, so it casts a shadow.
        let cross = crossPath(mm: mm)
        var shadow = context
        shadow.addFilter(.blur(radius: 0.35 * mm))
        shadow.fill(cross.offsetBy(dx: -light.dx * 0.55 * mm, dy: -light.dy * 0.55 * mm + 0.25 * mm),
                    with: .color(.black.opacity(0.55)))

        if design.stemShape == .box {
            // Box stem: a square wall around the cross keeps out dust and wobble.
            let outer = rounded(rect(0, 0, 5.8, 5.8, mm: mm), 0.6, mm: mm)
            let inner = rounded(rect(0, 0, 4.4, 4.4, mm: mm), 0.35, mm: mm)
            context.fill(outer, with: stemFill)
            context.fill(inner, with: .color(shade(stem, 0.55)))
            context.stroke(outer, with: .color(.white.opacity(0.25)), lineWidth: 0.15 * mm)
        }

        context.fill(cross, with: .linearGradient(
            Gradient(colors: [shade(stem, 1.3), shade(stem, 0.95)]), startPoint: up, endPoint: down))
        // Highlight along the cross's lit edges.
        context.stroke(cross, with: .linearGradient(Gradient(colors: [.white.opacity(0.45), .clear]),
                                                    startPoint: up, endPoint: down), lineWidth: 0.15 * mm)
    }

    /// The Cherry MX cross: 4.1 mm across, 1.17 mm horizontal and 1.31 mm vertical arms.
    private func crossPath(mm: CGFloat) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect(0, 0, 4.1, 1.17, mm: mm), cornerSize: CGSize(width: 0.2 * mm, height: 0.2 * mm))
        p.addRoundedRect(in: rect(0, 0, 1.31, 4.1, mm: mm), cornerSize: CGSize(width: 0.2 * mm, height: 0.2 * mm))
        return p
    }

    /// Opacity of the top housing, how glossy it is, and how bright its lit rim is.
    private func materialLook(_ m: SwitchDesign.Material) -> (Double, Double, Double) {
        switch m {
        case .nylon: (1, 0.18, 0.18)          // matte, opaque
        case .pom: (0.97, 0.35, 0.4)          // waxy, soft sheen
        case .polycarbonate: (0.28, 0.6, 0.7) // clear, glossy
        }
    }

    private func shade(_ c: RGB, _ k: Double) -> Color {
        Color(.sRGB, red: min(1, c.r * k), green: min(1, c.g * k), blue: min(1, c.b * k))
    }
}
