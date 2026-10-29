import SwiftUI

/// The whole board: an aluminium case, a recessed plate, a row of keycaps,
/// and a faded mirror image below it, like keys sitting on a glossy desk.
struct KeyboardView: View {
    @ObservedObject var store: DockStore
    @ObservedObject var prefs: Preferences
    let sound: SoundEngine
    /// Fixed key size for the settings preview; nil uses the user's key size.
    var unitOverride: CGFloat?
    /// The preview plays sounds but doesn't launch apps.
    var launchesApps = true

    @State private var pressedID: String?
    @State private var hoveredID: String?

    var body: some View {
        let unit = unitOverride ?? CGFloat(prefs.keySize)
        VStack(spacing: unit * BoardLayout.reflectionGap) {
            board(unit: unit, interactive: true)
            if prefs.showReflection {
                board(unit: unit, interactive: false)
                    .scaleEffect(x: 1, y: -1)
                    .frame(height: unit * BoardLayout.reflection, alignment: .top)
                    .clipped()
                    .mask(LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        // Room for the name tooltip above and the case shadow around the board.
        .padding(.top, unit * BoardLayout.top)
        .padding(.horizontal, unit * BoardLayout.side)
        .padding(.bottom, prefs.showReflection ? 0 : unit * BoardLayout.bottom)
        // The tooltip lives outside the board's drawingGroup, which would clip it.
        .overlay(alignment: .topLeading) {
            if pressedID == nil, let id = hoveredID, let (index, app) = hoveredApp(id) {
                tooltip(app.displayName).position(x: BoardLayout(unit: unit).keyFrame(index, in: store.slots)?.midX ?? 0, y: unit * 0.32)
            }
        }
    }

    private func hoveredApp(_ id: String) -> (Int, DockApp)? {
        for (i, slot) in store.slots.enumerated() {
            if case .app(let app) = slot.kind, app.id == id { return (i, app) }
        }
        return nil
    }

    private func board(unit: CGFloat, interactive: Bool) -> some View {
        let finish = CaseFinish(prefs.caseColor)
        let light = prefs.lighting
        // Concentric corners: each layer's radius is the one inside it plus the gap between them.
        let plateRadius = KeycapView.capRadius(unit: unit, profile: prefs.profile) + unit * BoardLayout.plate
        let caseRadius = plateRadius + unit * BoardLayout.caseWall
        // Each run of keys between Dock spacers sits in its own recessed well,
        // with the case surface showing between wells.
        return HStack(spacing: unit * BoardLayout.gap) {
            // Groups are identified by position so a well doesn't re-enter when its first key changes.
            ForEach(Array(BoardLayout.groups(store.slots).enumerated()), id: \.offset) { _, group in
                HStack(spacing: unit * BoardLayout.spacing) {
                    ForEach(group, id: \.app.id) { index, app in
                        let key = KeycapView(app: app, unit: unit, legend: prefs.legend, style: prefs.keyStyle, isPressed: pressedID == app.id)
                        Group {
                            if interactive {
                                key
                                .contentShape(Rectangle())
                                .onHover { hoveredID = $0 ? app.id : (hoveredID == app.id ? nil : hoveredID) }
                                .gesture(press(app, unit: unit, pan: pan(index)))
                            } else {
                                key
                            }
                        }
                        .transition(keyTransition)
                    }
                }
                .padding(unit * BoardLayout.plate)
                .background(well(for: group, unit: unit, radius: plateRadius, finish: finish))
            }
        }
        .padding(unit * BoardLayout.caseWall)
        .background(
            RoundedRectangle(cornerRadius: caseRadius, style: .continuous)
                .fill(LinearGradient(colors: finish.body, startPoint: .top, endPoint: .bottom))
                .overlay(
                    // Machined top bevel catching the light.
                    RoundedRectangle(cornerRadius: caseRadius, style: .continuous).strokeBorder(
                        LinearGradient(colors: [.white.opacity(finish.bevel), .clear, .black.opacity(0.4)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
        )
        // Rasterise the board into one layer; it only redraws when state changes.
        .drawingGroup()
        .shadow(color: .black.opacity(interactive ? 0.6 * light.shadow : 0), radius: unit * 0.18,
                x: unit * light.shadowOffsetX * 2, y: unit * (0.04 + 0.1 * light.shadow))
        .animation(pressedID == nil ? .spring(response: 0.18, dampingFraction: 0.55) : .easeOut(duration: 0.04),
                   value: pressedID)
        // Keys arriving, leaving and the board resizing all move together.
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.86),
                   value: store.slots.map(\.id))
        .animation(.easeOut(duration: 0.2), value: unit)
    }

    /// The recess a group of keys sits in, filled according to the user's choice.
    private func well(for group: [BoardLayout.Key], unit: CGFloat, radius: CGFloat, finish: CaseFinish) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = Color.black.opacity(prefs.gapFill == .plate || prefs.gapFill == .backlight ? 0.7 : 0.45)
        let base: Color = switch prefs.gapFill {
        case .plate: finish.plate
        case .backlight: finish.backlitPlate
        case .body: finish.recess
        case .color: prefs.gapColor.color
        }
        return ZStack {
            shape.fill(base.shadow(.inner(color: inner, radius: unit * 0.06, y: unit * 0.03)))
            if prefs.gapFill == .backlight {
                // Light from LEDs under each switch, spilling into the gaps around the cap.
                // Added with plusLighter so overlapping glows brighten like real light.
                HStack(spacing: unit * BoardLayout.spacing) {
                    ForEach(group, id: \.app.id) { _, app in
                        let (h, s, _) = app.palette.base.hsv
                        let glow = RGB(h: h, s: min(1, s * 1.1), v: 1).color
                        // The gradient ends inside its own frame so no hard edge shows,
                        // then the frame is scaled up so the light spills past the cap.
                        RadialGradient(
                            stops: [
                                .init(color: glow.opacity(0.8 * prefs.backlight), location: 0.45),
                                .init(color: glow.opacity(0.25 * prefs.backlight), location: 0.72),
                                .init(color: .clear, location: 1),
                            ],
                            center: .center, startRadius: 0, endRadius: unit * 0.5
                        )
                        .frame(width: unit, height: unit)
                        .scaleEffect(1.65)
                    }
                }
                .padding(unit * BoardLayout.plate)
                .blendMode(.plusLighter)
            }
        }
        .clipShape(shape)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Keys scale up and fade in on arrival (ease-out), and leave faster (ease-in).
    /// Reduce Motion keeps just the fade.
    private var keyTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .scale(scale: 0.4).combined(with: .opacity).animation(.easeOut(duration: 0.28)),
            removal: .scale(scale: 0.4).combined(with: .opacity).animation(.easeIn(duration: 0.18))
        )
    }

    private func press(_ app: DockApp, unit: CGFloat, pan: Float) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard pressedID != app.id else { return }
                pressedID = app.id
                click(.down, pan: pan)
            }
            .onEnded { value in
                pressedID = nil
                if prefs.releaseSounds { click(.up, pan: pan) }
                if launchesApps, CGRect(x: 0, y: 0, width: unit, height: unit).contains(value.location) {
                    store.activate(app)
                }
            }
    }

    private func click(_ stroke: Stroke, pan: Float) {
        guard prefs.soundEnabled else { return }
        sound.play(stroke, type: prefs.switchType, volume: Float(prefs.volume), pan: pan)
    }

    /// Spreads keys across the stereo field, kept narrow so it reads as one keyboard.
    private func pan(_ index: Int) -> Float {
        let count = max(store.slots.count - 1, 1)
        return Float(index) / Float(count) * 1.2 - 0.6
    }

    private func tooltip(_ text: String) -> some View {
        Text(text)
            .typeStyle(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.78)))
            .fixedSize()
    }
}

/// Where each key sits inside the board view, in its top-left coordinate space.
/// Shared by the SwiftUI layout, the tooltip, and right-click hit-testing.
struct BoardLayout {
    static let top = 0.6, side = 0.3, caseWall = 0.12, plate = 0.14, spacing = 0.07, gap = 0.22
    static let reflectionGap = 0.04, reflection = 0.55, bottom = 0.2
    let unit: CGFloat

    /// Height of the view below the board's case: the reflection, or a margin for the shadow.
    static func belowBoard(unit: CGFloat, reflection showsReflection: Bool) -> CGFloat {
        unit * (showsReflection ? reflectionGap + reflection : bottom)
    }

    typealias Key = (index: Int, app: DockApp)

    /// Splits the slots at spacers into runs of keys; each run gets its own well.
    static func groups(_ slots: [DockSlot]) -> [[Key]] {
        var groups: [[Key]] = [[]]
        for (i, slot) in slots.enumerated() {
            switch slot.kind {
            case .spacer: if !groups[groups.count - 1].isEmpty { groups.append([]) }
            case .app(let app): groups[groups.count - 1].append((i, app))
            }
        }
        return groups.filter { !$0.isEmpty }
    }

    /// Frames of every key, keyed by slot index.
    func keyFrames(in slots: [DockSlot]) -> [(index: Int, app: DockApp, frame: CGRect)] {
        let y = unit * (Self.top + Self.caseWall + Self.plate)
        var x = unit * (Self.side + Self.caseWall)
        var out: [(Int, DockApp, CGRect)] = []
        for group in Self.groups(slots) {
            x += unit * Self.plate
            for key in group {
                out.append((key.index, key.app, CGRect(x: x, y: y, width: unit, height: unit)))
                x += unit * (1 + Self.spacing)
            }
            x += unit * (Self.plate - Self.spacing + Self.gap)
        }
        return out
    }

    func keyFrame(_ index: Int, in slots: [DockSlot]) -> CGRect? {
        keyFrames(in: slots).first { $0.index == index }?.frame
    }

    func app(at point: CGPoint, in slots: [DockSlot]) -> DockApp? {
        keyFrames(in: slots).first { $0.frame.contains(point) }?.app
    }
}
