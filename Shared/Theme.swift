import SwiftUI

// Design tokens from the approved «البطاقة» design (contrast-checked: label/label2/label3 ≥ 4.5:1 on their surfaces).

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }

    init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        self.init(hex: UInt32(s, radix: 16) ?? 0xA19DA8)
    }
}

/// Accent tokens shared by every background.
enum Tok {
    static let tint = Color(hex: 0xCB2A5C)
    static let tintInk = Color(hex: 0xFF9DB4)
    static let gold = Color(hex: 0xE8CB94)
    static let positive = Color(hex: 0x5DD39E)
    static let danger = Color(hex: 0xFF7A7A)
    static let warning = Color(hex: 0xF7BC5C)
}

/// One of the three backgrounds offered in Settings. Deep maroon (wine) is the default.
struct Palette {
    let bg: Color, bgTop: Color, surface: Color, surface2: Color, separator: Color
    let label: Color, label2: Color, label3: Color, track: Color
    let glass: Color, tintContainer: Color, onTintContainer: Color

    static let wine = Palette(bg: Color(hex: 0x17080F), bgTop: Color(hex: 0x2C0E1B), surface: Color(hex: 0x24121B), surface2: Color(hex: 0x301A25),
                              separator: Color(hex: 0x432634), label: Color(hex: 0xF8F1F4), label2: Color(hex: 0xCDB9C1), label3: Color(hex: 0xB29AA4),
                              track: Color(hex: 0x432634), glass: Color(hex: 0x24121B, opacity: 0.72), tintContainer: Color(hex: 0x4A1A2C),
                              onTintContainer: Color(hex: 0xFFD0DC))
    static let navy = Palette(bg: Color(hex: 0x0B1020), bgTop: Color(hex: 0x19223D), surface: Color(hex: 0x151B2D), surface2: Color(hex: 0x1F2739),
                              separator: Color(hex: 0x2A3349), label: Color(hex: 0xF4F5F8), label2: Color(hex: 0xB8BECC), label3: Color(hex: 0x9AA2B4),
                              track: Color(hex: 0x2A3349), glass: Color(hex: 0x151B2D, opacity: 0.72), tintContainer: Color(hex: 0x3A1424),
                              onTintContainer: Color(hex: 0xFFD0DC))
    static let graphite = Palette(bg: Color(hex: 0x121114), bgTop: Color(hex: 0x26242B), surface: Color(hex: 0x1C1B1F), surface2: Color(hex: 0x27262B),
                                  separator: Color(hex: 0x34333A), label: Color(hex: 0xF5F4F6), label2: Color(hex: 0xBEBBC3), label3: Color(hex: 0xA19DA8),
                                  track: Color(hex: 0x34333A), glass: Color(hex: 0x1C1B1F, opacity: 0.72), tintContainer: Color(hex: 0x3A1424),
                                  onTintContainer: Color(hex: 0xFFD0DC))

    static func named(_ name: String) -> Palette {
        switch name {
        case "navy": return .navy
        case "graphite": return .graphite
        default: return .wine
        }
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.wine }

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Alexandria (OFL), bundled as static weights. Sizes scale with Dynamic Type.
enum AlxWeight {
    case light, regular, medium, semibold, bold
    var postScript: String {
        switch self {
        case .light: return "Alexandria-Light"
        case .regular: return "Alexandria-Regular"
        case .medium: return "Alexandria-Medium"
        case .semibold: return "Alexandria-SemiBold"
        case .bold: return "Alexandria-Bold"
        }
    }
}

extension Font {
    static func alx(_ size: CGFloat, _ weight: AlxWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.postScript, size: size, relativeTo: style)
    }
}

/// Realistic 3D icon (Microsoft Fluent Emoji 3D, MIT).
struct Icon3D: View {
    let name: String
    var size: CGFloat = 44
    var shadow: Bool = false

    var body: some View {
        Image("i3d-" + name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(shadow ? 0.35 : 0), radius: shadow ? 5 : 0, x: 0, y: shadow ? 5 : 0)
            .accessibilityHidden(true)
    }
}
