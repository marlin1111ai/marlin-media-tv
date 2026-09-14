//
//  Theme.swift
//  Marlin Media TV
//
//  Nocturne design tokens (Design/_ds/…/styles.css) plus the values the 17 frames in
//  Design/"Marlin Media.dc.html" use inline. Screens are 1920 × 1080 at 1×; content sits
//  80 pt from the sides. Fonts are the system font (no bundled Inter — see the pass-1 report).
//

import SwiftUI

enum Nocturne {
    // Roles (styles.css :root)
    static let bg = Color(hex: 0x161826)
    static let surface = Color(hex: 0x232532)
    static let text = Color(hex: 0xE9E9ED)
    static let accent = Color(hex: 0x9184D9)

    // Inline values the frames use
    static let playerBg = Color(hex: 0x07080C)     // frames 10–15 ground
    static let panelBg = Color(hex: 0x1E2030)      // frames 07, 11, 12 dialog/panel ground
    static let controlBg = Color(hex: 0x1C1E2D)    // sort control, badge ground
    static let rowRule = Color(hex: 0x2F3240)      // edition rows / sort menu rules
    static let panelRule = Color(hex: 0x2B2E3C)    // panel + episode row rules
    static let badgeBg = Color(red: 18 / 255, green: 20 / 255, blue: 32 / 255, opacity: 0.78)

    // Accent ramp
    static let accent100 = Color(hex: 0xF5F4FF)
    static let accent200 = Color(hex: 0xE7E5FE)
    static let accent300 = Color(hex: 0xD2CEFD)
    static let accent400 = Color(hex: 0xB5ABFC)
    static let accent700 = Color(hex: 0x5D5294)
    static let accent800 = Color(hex: 0x423A6A)
    static let accent900 = Color(hex: 0x2B2741)

    // Neutral ramp
    static let neutral100 = Color(hex: 0xF3F5FE)
    static let neutral200 = Color(hex: 0xE4E7F5)
    static let neutral300 = Color(hex: 0xCFD3E5)
    static let neutral400 = Color(hex: 0xB2B6CA)
    static let neutral500 = Color(hex: 0x9397AB)
    static let neutral600 = Color(hex: 0x75798C)
    static let neutral700 = Color(hex: 0x595D6C)
    static let neutral800 = Color(hex: 0x3F424D)
    static let neutral900 = Color(hex: 0x292B31)

    /// The library ground: radial-gradient(120% 80% at 12% 0%, #1d2033 0%, #161826 55%, #131522 100%)
    static var libraryGround: some View {
        EllipticalGradient(
            stops: [.init(color: Color(hex: 0x1D2033), location: 0),
                    .init(color: Color(hex: 0x161826), location: 0.55),
                    .init(color: Color(hex: 0x131522), location: 1)],
            center: UnitPoint(x: 0.12, y: 0), startRadiusFraction: 0, endRadiusFraction: 1.1)
    }

    /// Frame 17 ground: radial-gradient(90% 80% at 50% 30%, #1d1f2f 0%, #161826 55%, #101220 100%)
    static var errorGround: some View {
        EllipticalGradient(
            stops: [.init(color: Color(hex: 0x1D1F2F), location: 0),
                    .init(color: Color(hex: 0x161826), location: 0.55),
                    .init(color: Color(hex: 0x101220), location: 1)],
            center: UnitPoint(x: 0.5, y: 0.3), startRadiusFraction: 0, endRadiusFraction: 0.9)
    }

    /// Frame 09 ground: radial-gradient(90% 80% at 20% 0%, #1f2235 0%, #161826 55%, #131522 100%)
    static var videoGround: some View {
        EllipticalGradient(
            stops: [.init(color: Color(hex: 0x1F2235), location: 0),
                    .init(color: Color(hex: 0x161826), location: 0.55),
                    .init(color: Color(hex: 0x131522), location: 1)],
            center: UnitPoint(x: 0.2, y: 0), startRadiusFraction: 0, endRadiusFraction: 0.9)
    }

    /// The poster placeholder: linear-gradient(155deg, #2b2741 0%, #1b1d2b 62%, #232532 100%)
    static var posterPlaceholder: some View {
        LinearGradient(
            stops: [.init(color: Color(hex: 0x2B2741), location: 0),
                    .init(color: Color(hex: 0x1B1D2B), location: 0.62),
                    .init(color: Color(hex: 0x232532), location: 1)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    /// A colour from a 24-bit RGB hex value (sRGB).
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Font {
    /// The system font at a design size and weight (design 400 = .regular, 500 = .medium, 600 = .semibold).
    static func nocturne(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

/// A button that draws nothing of its own: the label carries the frame's focus treatment
/// through `@Environment(\.isFocused)`.
struct BareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// The uppercase tracked kicker used across the frames (20 px, .16 em, #9397ab).
struct Kicker: View {
    let text: String
    var size: CGFloat = 20
    var color: Color = Nocturne.neutral500

    var body: some View {
        Text(text.uppercased())
            .font(.nocturne(size, .medium))
            .kerning(size * 0.16)
            .foregroundStyle(color)
    }
}

/// The 4K / HDR / resolution badge (frames 01, 06, 07).
struct Badge: View {
    let text: String
    var accent = false
    var size: CGFloat = 15
    var ground: Color = Nocturne.badgeBg

    var body: some View {
        Text(text)
            .font(.nocturne(size, .semibold))
            .kerning(size * 0.07)
            .foregroundStyle(accent ? Nocturne.accent300 : Nocturne.neutral200)
            .padding(.vertical, size == 15 ? 6 : 7)
            .padding(.horizontal, size == 15 ? 9 : 10)
            .background(accent ? Nocturne.accent.opacity(0.16) : ground, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent ? Nocturne.accent : Nocturne.neutral600, lineWidth: 1))
    }
}

/// The "·" separator of the meta rows.
struct Dot: View {
    var body: some View {
        Text("·").foregroundStyle(Nocturne.neutral700)
    }
}
