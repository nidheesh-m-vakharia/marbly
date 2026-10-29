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

    /// A key being dragged to a new place. Other keys in its well shift to show where it
    /// would land; nothing is committed until it's dropped.
    private struct DragState {
        let id: String
        let group: Int
        let startIndex: Int
        let original: [String]
        var order: [String]
        var translation: CGFloat
    }
    @State private var drag: DragState?
    /// 0 resting, 1 fully lifted: the dragged cap rises off its switch.
    @State private var lift: CGFloat = 0
    /// The key just dropped, settling back onto its switch.
    @State private var droppedID: String?
    @State private var dropCount = 0

    /// For `--snapshot-drag`: start mid-drag, the given key moved to `to`.
    func frozenDrag(id: String, group: Int, from: Int, to: Int, ids: [String], unit: CGFloat) -> KeyboardView {
        var copy = self
        var order = ids
        order.remove(at: from)
        order.insert(id, at: to)
        let step = unit * (1 + BoardLayout.spacing)
        copy._drag = State(initialValue: DragState(id: id, group: group, startIndex: from, original: ids, order: order,
                                                   translation: CGFloat(to - from) * step + unit * 0.2))
        copy._lift = State(initialValue: 1)
        return copy
    }

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
            if pressedID == nil, drag == nil, let id = hoveredID, let (index, app) = hoveredApp(id) {
                tooltip(app.displayName).position(x: BoardLayout(unit: unit).keyFrame(index, in: store.slots)?.midX ?? 0, y: unit * 0.32)
            }
        }
        // The lifted cap, also outside the drawingGroup so it can rise above the case.
        .overlay(alignment: .topLeading) {
            if let d = drag, let (index, app) = hoveredApp(d.id),
               let frame = BoardLayout(unit: unit).keyFrame(index, in: store.slots) {
                KeycapView(app: app, unit: unit, legend: prefs.legend, style: prefs.keyStyle, isPressed: false)
                    .scaleEffect(1 + 0.06 * lift)
                    .shadow(color: .black.opacity(0.45 * lift), radius: unit * 0.18 * lift, y: unit * 0.24 * lift)
                    .position(x: frame.midX + d.translation, y: frame.midY - unit * 0.3 * lift)
                    .allowsHitTesting(false)
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
            ForEach(Array(BoardLayout.groups(store.slots).enumerated()), id: \.offset) { groupIndex, group in
                let ids = group.map(\.app.id)
                HStack(spacing: unit * BoardLayout.spacing) {
                    ForEach(Array(group.enumerated()), id: \.element.app.id) { position, entry in
                        let app = entry.app
                        let step = unit * (1 + BoardLayout.spacing)
                        let shown = previewPosition(of: app.id, at: position, group: groupIndex)
                        let held = drag.flatMap { $0.order.firstIndex(of: $0.id) } ?? shown
                        // Keys further from the held one move a beat later, so the shift ripples.
                        let stagger = Double(abs(shown - held)) * 0.035
                        Group {
                            if drag?.id == app.id {
                                // The cap is lifted off: the switch underneath shows in its slot.
                                SwitchView(design: .forSwitch(prefs.switchType), unit: unit, lighting: prefs.lighting)
                            } else {
                                let key = KeycapView(app: app, unit: unit, legend: prefs.legend, style: prefs.keyStyle,
                                                     isPressed: pressedID == app.id)
                                if interactive {
                                    key
                                    .contentShape(Rectangle())
                                    .onHover { hoveredID = $0 ? app.id : (hoveredID == app.id ? nil : hoveredID) }
                                } else {
                                    key
                                }
                            }
                        }
                        .gesture(press(app, unit: unit, pan: pan(entry.index), group: groupIndex, position: position, ids: ids),
                                 including: interactive ? .all : .none)
                        // Shifting to make room: slide over with a spring, staggered by distance.
                        .offset(x: CGFloat(shown - position) * step)
                        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.82).delay(stagger),
                                   value: shown)
                        // …lifting a little as it goes, then setting back down.
                        .keyframeAnimator(initialValue: 0.0, trigger: shown) { content, value in
                            content.offset(y: -value * unit * 0.12).scaleEffect(1 + value * 0.03)
                        } keyframes: { _ in
                            LinearKeyframe(0.0, duration: stagger)
                            SpringKeyframe(reduceMotion ? 0.0 : 1.0, duration: 0.12)
                            SpringKeyframe(0.0, duration: 0.24)
                        }
                        // The dropped key settles from its lifted height onto the switch.
                        .keyframeAnimator(initialValue: 0.0, trigger: dropCount) { content, value in
                            content.offset(y: droppedID == app.id ? -value * unit * 0.3 : 0)
                        } keyframes: { _ in
                            LinearKeyframe(1.0, duration: 0.001)
                            SpringKeyframe(0.0, duration: reduceMotion ? 0.12 : 0.34, spring: .bouncy)
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

    /// Where a key shows during a drag: its place in the previewed order.
    private func previewPosition(of id: String, at position: Int, group: Int) -> Int {
        guard let d = drag, d.group == group, let i = d.order.firstIndex(of: id) else { return position }
        return i
    }

    /// Pinned apps can be moved, except Finder (always first) and window keys.
    private func canDrag(_ app: DockApp) -> Bool {
        launchesApps && app.isPinned && app.windowNumber == nil
    }

    /// A press that becomes a drag once it moves sideways: a click opens the app, a drag
    /// lifts the cap and reorders the well, a drop writes the new order to the Dock.
    private func press(_ app: DockApp, unit: CGFloat, pan: Float, group: Int, position: Int, ids: [String]) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if var d = drag {
                    guard d.id == app.id else { return }
                    let step = unit * (1 + BoardLayout.spacing)
                    let lower = -CGFloat(d.startIndex) * step - unit * 0.3
                    let upper = CGFloat(d.original.count - 1 - d.startIndex) * step + unit * 0.3
                    d.translation = min(max(value.translation.width, lower), upper)
                    let target = min(max(Int(((CGFloat(d.startIndex) * step + d.translation) / step).rounded()), 0),
                                     d.order.count - 1)
                    if let current = d.order.firstIndex(of: d.id), target != current {
                        d.order.remove(at: current)
                        d.order.insert(d.id, at: target)
                    }
                    drag = d
                    return
                }
                if pressedID != app.id {
                    pressedID = app.id
                    click(.down, pan: pan)
                }
                if canDrag(app), abs(value.translation.width) > 6 {
                    // Pick the cap up off its switch.
                    pressedID = nil
                    if prefs.releaseSounds { click(.up, pan: pan) }
                    lift = 0
                    drag = DragState(id: app.id, group: group, startIndex: position, original: ids, order: ids,
                                     translation: value.translation.width)
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.26, dampingFraction: 0.7)) {
                        lift = 1
                    }
                }
            }
            .onEnded { value in
                if let d = drag, d.id == app.id {
                    drop(d, pan: pan)
                    return
                }
                pressedID = nil
                if prefs.releaseSounds { click(.up, pan: pan) }
                if launchesApps, CGRect(x: 0, y: 0, width: unit, height: unit).contains(value.location) {
                    store.activate(app)
                }
            }
    }

    /// Puts the cap down in its new place. The board's order and every offset change in
    /// one step without animation, so nothing jumps; then the cap settles onto its switch.
    private func drop(_ d: DragState, pan: Float) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            store.reorder(group: d.original, to: d.order, moved: d.id)
            drag = nil
            lift = 0
            droppedID = d.id
            dropCount += 1
        }
        click(.down, pan: pan)
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
