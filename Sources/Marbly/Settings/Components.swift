import SwiftUI

// Components: flat surfaces, hairline rings, selection shown by a tinted fill,
// generous spacing on an 8 pt grid. Every pressable shrinks to 97% while held.

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).typeStyle(.title).foregroundStyle(Radix.slate12)
            Text(subtitle).typeStyle(.caption).foregroundStyle(Radix.slate11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A heading with a muted line explaining what the group is for.
struct SectionHeader: View {
    let title: String
    let detail: String

    init(_ title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).typeStyle(.bodyMedium).foregroundStyle(Radix.slate12)
            Text(detail).typeStyle(.caption).foregroundStyle(Radix.slate11)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }
}

/// A titled group of rows in a settings box: gray-2, 4 pt inset, 10 pt corners
/// with 6 pt rows inside (concentric). No outlines, no dividers.
struct SettingsSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(_ title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, detail: detail)
            VStack(spacing: 2) { content }
                .padding(4)
                .mutedBox(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// A label and description on the left, a control on the right. At least 52 pt tall.
struct SettingRow<Control: View>: View {
    let label: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).typeStyle(.body).foregroundStyle(Radix.slate12)
                Text(detail).typeStyle(.caption).foregroundStyle(Radix.slate11)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            // Controls keep their natural size; the description wraps instead.
            control.fixedSize().layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
    }
}

// MARK: - Switch

/// A pill switch. Off: a grey track. On: accent fill. The white knob travels with a
/// slight overshoot. No outlines.
struct PillSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        PillSwitch(isOn: configuration.$isOn, label: configuration.label)
    }
}

private struct PillSwitch<Label: View>: View {
    @Binding var isOn: Bool
    let label: Label
    @Environment(\.isEnabled) private var isEnabled
    @State private var pressed = false

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Radix.indigo9 : Radix.slate5)
            Circle()
                .fill(isOn ? Color.white : Radix.slate11)
                .frame(width: 18, height: 18)
                .padding(3)
        }
        .frame(width: 40, height: 24)
        .scaleEffect(pressed ? Motion.pressedScale : 1)
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Capsule())
        .onTapGesture { withAnimation(Motion.spring) { isOn.toggle() } }
        .onLongPressGesture(minimumDuration: 0, pressing: { p in withAnimation(Motion.easeOut) { pressed = p } }, perform: {})
        .animation(Motion.spring, value: isOn)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAction { isOn.toggle() }
    }
}

// MARK: - Segmented control

/// Options on a filled track. The chosen one gets an indigo fill and indigo text.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { withAnimation(Motion.easeOut) { selection = option } } label: {
                    Text(title(option))
                        .typeStyle(.caption)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(selected ? Radix.indigo11 : Radix.slate11)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Radix.indigo4)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Radix.slate4, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Slider

/// A slider drawn as a filled track: the label and value sit inside it, the filled
/// part shows the amount, and a thin bar marks the position. The description sits below.
struct SliderRow: View {
    let label: String
    let detail: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    let format: (Double) -> String

    @State private var dragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let inner = geo.size.width - 8
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let fill = max(16, inner * fraction)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Radix.slate3)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Radix.slate5)
                        .frame(width: fill)
                        .padding(4)
                    // Position marker: a short vertical bar at the fill's edge.
                    Capsule()
                        .fill(Radix.slate12)
                        .frame(width: 4, height: dragging ? 24 : 20)
                        .offset(x: 4 + fill - 10)
                    HStack {
                        Text(label).typeStyle(.captionMedium).foregroundStyle(Radix.slate12)
                        Spacer()
                        Text(format(value)).typeStyle(.caption).monospacedDigit().foregroundStyle(Radix.slate11)
                    }
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        set(fraction: (g.location.x - 4) / inner)
                    }
                    .onEnded { _ in dragging = false })
                .animation(Motion.spring, value: dragging)
            }
            .frame(height: 44)

            Text(detail).typeStyle(.caption).foregroundStyle(Radix.slate11)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            let delta = step ?? (range.upperBound - range.lowerBound) / 20
            value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? delta : -delta)))
        }
    }

    private func set(fraction: Double) {
        var v = range.lowerBound + min(1, max(0, fraction)) * (range.upperBound - range.lowerBound)
        if let step { v = (v / step).rounded() * step }
        value = v
    }
}

// MARK: - Buttons

/// Shrinks slightly while held.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .animation(Motion.easeOut, value: configuration.isPressed)
    }
}

/// Pill buttons. `.action` (accent) is for doing the thing; `.secondary` for everything else.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case action, secondary }
    let kind: Kind
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = switch kind {
        case .action: hovering || configuration.isPressed ? Radix.indigo10 : Radix.indigo9
        case .secondary: hovering || configuration.isPressed ? Radix.slate5 : Radix.slate4
        }
        return configuration.label
            .typeStyle(.captionMedium)
            .foregroundStyle(kind == .action ? Color.white : Radix.slate12)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(fill, in: Capsule())
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .onHover { hovering = $0 }
            .animation(Motion.easeOut, value: hovering)
            .animation(Motion.easeOut, value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View { Button(title, action: action).buttonStyle(PillButtonStyle(kind: .action)) }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View { Button(title, action: action).buttonStyle(PillButtonStyle(kind: .secondary)) }
}

// MARK: - Badge and callout

/// A tinted pill: soft hue fill, step-11 text.
struct StatusBadge: View {
    let granted: Bool
    let grantedText: String
    let missingText: String

    var body: some View {
        HStack(spacing: 6) {
            Solar(granted ? .checkCircle : .dangerCircle, size: 14)
            Text(granted ? grantedText : missingText)
        }
        .typeStyle(.captionMedium)
        .foregroundStyle(granted ? Radix.green11 : Radix.amber11)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .fixedSize()
        .background(granted ? Radix.green4 : Radix.amber4, in: Capsule())
    }
}

/// An inline note on a soft tinted fill.
struct Callout: View {
    let icon: SolarIcon
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Solar(icon, size: 18).foregroundStyle(Radix.amber11)
            Text(text).typeStyle(.caption).foregroundStyle(Radix.slate12)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Radix.amber3, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preview

/// Live board at the top of the visual pages, fitted to the space available.
struct BoardPreview: View {
    @ObservedObject var store: DockStore
    @ObservedObject var prefs: Preferences
    let sound: SoundEngine
    private let height: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            KeyboardView(store: store, prefs: prefs, sound: sound, unitOverride: unit(for: geo.size.width),
                         launchesApps: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: height)
        .mutedBox(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("Preview of your keyboard")
    }

    /// Largest key size at which the whole board fits, capped at the user's own size.
    private func unit(for width: CGFloat) -> CGFloat {
        let groups = BoardLayout.groups(store.slots)
        let keys = groups.reduce(0) { $0 + $1.count }
        let n = Double(groups.count)
        let across = 2 * (BoardLayout.side + BoardLayout.caseWall) + n * 2 * BoardLayout.plate
            + Double(keys) * (1 + BoardLayout.spacing) + max(0, n - 1) * BoardLayout.gap
        let down = BoardLayout.top + 2 * (BoardLayout.caseWall + BoardLayout.plate) + 1
            + (prefs.showReflection ? BoardLayout.reflectionGap + BoardLayout.reflection : BoardLayout.bottom)
        return min(CGFloat(prefs.keySize), (width - 32) / across, (height - 16) / down)
    }
}
