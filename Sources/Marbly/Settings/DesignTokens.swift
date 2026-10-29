import AppKit
import SwiftUI

/// Radix Colors scales (radix-ui.com/colors), each with its light and dark value.
enum Radix {
    static let slate1 = pair("#FCFCFD", "#111113")
    static let slate2 = pair("#F9F9FB", "#18191B")
    static let slate3 = pair("#F0F0F3", "#212225")
    static let slate4 = pair("#E8E8EC", "#272A2D")
    static let slate5 = pair("#E0E1E6", "#2E3135")
    static let slate6 = pair("#D9D9E0", "#363A3F")
    static let slate7 = pair("#CDCED6", "#43484E")
    static let slate8 = pair("#B9BBC6", "#5A6169")
    static let slate9 = pair("#8B8D98", "#696E77")
    static let slate10 = pair("#80838D", "#777B84")
    static let slate11 = pair("#60646C", "#B0B4BA")
    static let slate12 = pair("#1C2024", "#EDEEF0")

    // Alpha scales: translucent slate, for text and overlays that sit on any surface.
    static let slateA2 = pair("#00005506", "#D8F4F609")
    static let slateA3 = pair("#0000330F", "#DDEAF814")
    static let slateA4 = pair("#00002D17", "#D3EDF81D")
    static let slateA5 = pair("#0009321F", "#D9EDFE25")
    static let slateA6 = pair("#00002F26", "#D6EBFD30")
    static let slateA7 = pair("#00062E32", "#D9EDFF40")
    static let slateA10 = pair("#00071B7F", "#E5EDFD7B")
    static let slateA11 = pair("#0007149F", "#F1F7FEB5")
    static let slateA12 = pair("#000509E3", "#FCFDFFEF")
    static let indigoA3 = pair("#0047F112", "#2F62FF3C")
    static let indigoA4 = pair("#0044FF1E", "#3361FF51")
    static let greenA3 = pair("#00A43319", "#02BB5323")
    static let amberA3 = pair("#FFEE0047", "#FA820022")

    static let indigo3 = pair("#EDF2FE", "#182449")
    static let indigo4 = pair("#E1E9FF", "#1D2E62")
    static let indigo9 = pair("#3E63DD", "#3E63DD")
    static let indigo10 = pair("#3358D4", "#5472E4")
    static let indigo11 = pair("#3A5BC7", "#9EB1FF")

    static let amber4 = pair("#FFEE9C", "#3F2700")
    static let green4 = pair("#D6F1DF", "#113B29")

    static let green3 = pair("#E6F6EB", "#132D21")
    static let green11 = pair("#218358", "#3DD68C")
    static let amber3 = pair("#FFF7C2", "#302008")
    static let amber11 = pair("#AB6400", "#FFCA16")

    /// Hex as #RRGGBB or #RRGGBBAA.
    private static func pair(_ light: String, _ dark: String) -> Color {
        let l = nsColor(light), d = nsColor(dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
        })
    }
}

private func nsColor(_ hex: String) -> NSColor {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let rgb = RGB(hex: String(digits.prefix(6)))!
    let alpha = digits.count == 8 ? Double(UInt8(digits.suffix(2), radix: 16)!) / 255 : 1
    return NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
}

/// Muted box: a flat gray-2 surface. No outline, no shadow.
extension View {
    func mutedBox<S: InsettableShape>(_ shape: S, tint: Color? = nil) -> some View {
        self.background(tint ?? Radix.slate2, in: shape)
    }
}

/// Motion shared by every control.
enum Motion {
    /// The default ease-out curve, cubic-bezier(0.22, 1, 0.36, 1).
    static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.15)
    /// A small overshoot for knobs and thumbs, cubic-bezier(0.34, 1.56, 0.64, 1).
    static let spring = Animation.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.2)
    /// Everything pressable shrinks slightly while held.
    static let pressedScale: CGFloat = 0.97
}

/// Type on a minor-second scale (×1.067) from a 16 px base, set in Open Runde.
/// Exactly four sizes, and weights stop at medium. Each style carries Inter's
/// Dynamic Metrics tracking and a 1.4 line height.
enum TypeScale: CaseIterable {
    case caption, captionMedium, body, bodyMedium, heading, title

    static let ratio = 1.067
    static func size(_ step: Int) -> CGFloat { 16 * pow(ratio, CGFloat(step)) }

    var size: CGFloat {
        switch self {
        case .caption, .captionMedium: Self.size(-2)   // 14.05
        case .body, .bodyMedium: Self.size(0)          // 16
        case .heading: Self.size(2)                    // 18.22
        case .title: Self.size(4)                      // 20.74
        }
    }

    var isMedium: Bool { self != .caption && self != .body }

    var font: Font { Font.custom(isMedium ? OpenRunde.medium : OpenRunde.regular, fixedSize: size) }
}

extension View {
    /// Font, tracking and line spacing for one of the four type styles.
    func typeStyle(_ style: TypeScale) -> some View {
        font(style.font)
            .tracking(OpenRunde.tracking(points: style.size))
            .lineSpacing(OpenRunde.lineSpacing(style.size))
    }
}
