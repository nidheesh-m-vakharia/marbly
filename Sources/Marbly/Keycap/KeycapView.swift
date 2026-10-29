import SwiftUI

/// A single sculpted keycap: darker side walls, a lighter dished top face set back
/// from the front edge, a specular sheen from the board's light, and a contact shadow.
/// All shading is gradients — no blurs — so a redraw is cheap.
struct KeycapView: View {
    let app: DockApp
    let unit: CGFloat
    let legend: LegendStyle
    let style: KeyStyle
    let isPressed: Bool

    private var light: Lighting { style.lighting }
    private var inset: (top: Double, side: Double, bottom: Double) { style.profile.inset }

    var body: some View {
        ZStack {
            contactShadow
            cap.offset(y: isPressed ? unit * style.profile.travel : 0)
        }
        .frame(width: unit, height: unit)
    }

    /// The top face uses the macOS icon shape (continuous corners, ~22.5% radius)
    /// so a full-bleed icon's corners line up with the face exactly.
    private var faceRadius: CGFloat { Self.faceRadius(unit: unit, profile: style.profile) }
    private var radius: CGFloat { Self.capRadius(unit: unit, profile: style.profile) }

    static func faceRadius(unit: CGFloat, profile: KeycapProfile) -> CGFloat {
        unit * (1 - 2 * profile.inset.side) * 0.225
    }

    /// Walls stay concentric with the face: its radius plus the wall thickness, eased a little.
    static func capRadius(unit: CGFloat, profile: KeycapProfile) -> CGFloat {
        faceRadius(unit: unit, profile: profile) + unit * profile.inset.side * 0.6
    }

    private var contactShadow: some View {
        let depth = light.shadow
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(
                colors: [.black.opacity(0), .black.opacity((isPressed ? 0.45 : 0.75) * depth)],
                startPoint: .top, endPoint: .bottom
            ))
            .offset(x: unit * light.shadowOffsetX, y: unit * (isPressed ? 0.03 : 0.04 + 0.07 * depth))
            .padding(.horizontal, unit * 0.02)
    }

    private var cap: some View {
        let p = app.palette
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack(alignment: .top) {
            // Side walls, lit from above, falling off toward the front edge.
            shape
                .fill(LinearGradient(colors: [p.wallLight.color, p.wallDark.color], startPoint: .top, endPoint: .bottom))
                .overlay(
                    // Left/right walls turn toward or away from the light.
                    shape.fill(LinearGradient(
                        stops: [
                            .init(color: .black.opacity(light.leftWallShade), location: 0),
                            .init(color: .clear, location: 0.16),
                            .init(color: .clear, location: 0.84),
                            .init(color: .black.opacity(light.rightWallShade), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                )
                .overlay(shape.strokeBorder(.black.opacity(0.35), lineWidth: 0.5))

            face
                .padding(.top, unit * inset.top)
                .padding(.horizontal, unit * inset.side)
                .padding(.bottom, unit * inset.bottom)
        }
    }

    private var face: some View {
        let p = app.palette
        let shape = RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
        // Glossier light gives a brighter, tighter highlight.
        let peak = light.intensity * (0.55 + 0.35 * light.gloss)
        let falloff = 0.7 - 0.35 * light.gloss
        let dish = style.profile.dish
        return ZStack {
            shape.fill(LinearGradient(colors: [p.faceTop.color, p.base.color], startPoint: .top, endPoint: .bottom))
            // The legend sits under the shading so it reads as printed into the cap.
            legendView.clipShape(shape)

            // Concavity, blended into the legend rather than laid over it. In a dish the
            // wall nearest the light is in shade and the far wall catches it — the
            // reverse of a domed surface.
            shape.fill(LinearGradient(
                colors: [.black.opacity(dish * 4), .clear, .white.opacity(dish * 2.5)],
                startPoint: light.lightStart, endPoint: light.lightEnd
            ))
            .blendMode(.softLight)
            // The lowest point of the dish, darkened by multiplying.
            shape.fill(RadialGradient(
                colors: [Color(white: 1 - dish * 1.6), .white],
                center: .init(x: 0.5, y: 0.56), startRadius: 0, endRadius: unit * 0.36
            ))
            .blendMode(.multiply)
            // The rim's shadow falling into the dish along the top edge.
            shape.fill(LinearGradient(
                stops: [.init(color: Color(white: 1 - dish * 2), location: 0), .init(color: .white, location: 0.2)],
                startPoint: .top, endPoint: .bottom
            ))
            .blendMode(.multiply)
            // Specular reflection of the light source, added like real light.
            shape.fill(LinearGradient(
                stops: [
                    .init(color: .white.opacity(peak * 0.8), location: 0),
                    .init(color: .white.opacity(peak * 0.2), location: falloff * 0.6),
                    .init(color: .clear, location: falloff),
                ],
                startPoint: light.lightStart, endPoint: light.lightEnd
            ))
            .blendMode(.screen)
        }
        // Keep the blend modes inside the face.
        .compositingGroup()
            // A soft shaded edge where the face curves down into the walls.
            .overlay(shape.strokeBorder(p.wallDark.color.opacity(0.35), lineWidth: max(1, unit * 0.03)))
            // Polished rim where the top face meets the walls.
            .overlay(shape.strokeBorder(LinearGradient(
                colors: [.white.opacity(0.25 + 0.4 * light.intensity), .white.opacity(0.04)],
                startPoint: light.lightStart, endPoint: light.lightEnd
            ), lineWidth: 1))
            .overlay(alignment: .topTrailing) { led }
    }

    @ViewBuilder
    private var legendView: some View {
        switch legend {
        case .icon:
            // Fill the face edge to edge. A slight overscale pushes the icon's own
            // anti-aliased border outside the clip so no seam shows.
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.04)
                .overlay(alignment: .topLeading) { windowNumber }
        case .name:
            Text(app.name)
                .font(.custom(OpenRunde.medium, fixedSize: max(8, unit * 0.14)))
                .tracking(OpenRunde.tracking(points: max(8, unit * 0.14)))
                .foregroundStyle(app.palette.legend.color.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(unit * 0.07)
        }
    }

    /// Which window this is (1, 2, …), printed thick in the top-left corner like a
    /// keycap legend, on a plate in the key's own colour with black or white text.
    @ViewBuilder
    private var windowNumber: some View {
        if let n = app.windowNumber {
            let size = max(8, unit * 0.2)
            Text("\(n)")
                .font(.custom(OpenRunde.semibold, fixedSize: size))
                .monospacedDigit()
                .foregroundStyle(app.palette.legend.color)
                .frame(minWidth: size * 1.15)
                .padding(.horizontal, unit * 0.03)
                .padding(.vertical, unit * 0.005)
                .background(app.palette.base.color, in: RoundedRectangle(cornerRadius: unit * 0.06, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: unit * 0.015, y: unit * 0.01)
                .padding(unit * 0.06)
        }
    }

    /// Running indicator, styled like a Caps Lock LED.
    private var led: some View {
        let size = unit * 0.075
        return ZStack {
            Circle().fill(.black.opacity(0.35))
            if app.isRunning {
                Circle().fill(RadialGradient(
                    colors: [.white, Color(red: 0.55, green: 1, blue: 0.75)],
                    center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.6
                ))
                .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .padding(unit * 0.06)
    }
}
