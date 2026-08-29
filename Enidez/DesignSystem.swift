//
//  DesignSystem.swift
//  Enidez
//
//  Palette et typographie de « Un jour ».
//  Fond noir, un seul niveau d'emphase par écran, un point d'accent minuscule.
//

import SwiftUI

/// Couleurs de l'application, dérivées du brief de design.
enum Palette {
    /// Fond des écrans (noir pur).
    static let screen = Color.black
    /// Fond du canevas (légèrement plus clair que le noir).
    static let canvas = Color(hex: 0x0A0A0B)

    /// Surfaces sombres pour les cartes secondaires et les boutons ronds.
    static let surface = Color(hex: 0x0F0F12)
    static let surfaceRaised = Color(hex: 0x101013)

    /// Dégradé de la carte mise en avant.
    static let cardTop = Color(hex: 0x26262A)
    static let cardBottom = Color(hex: 0x17171A)

    /// Texte : un seul élément actif par écran, le reste s'efface.
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8A8A90)
    static let textTertiary = Color(hex: 0x55555A)
    static let textMuted = Color(hex: 0x6A6A6F)
    static let textFaint = Color(hex: 0x4A4A50)
    static let textGhost = Color(hex: 0x3F3F45)

    /// Accent : un point de couleur, jamais une surface.
    static let accent = Color(hex: 0xD8FF3E)
    /// Le sablier utilise un violet doux.
    static let hourglass = Color(hex: 0x7F739A)

    /// Filet discret pour les bordures et séparateurs.
    static let hairline = Color.white.opacity(0.07)
    static let separator = Color.white.opacity(0.06)
}

extension Color {
    /// Initialise une couleur à partir d'un entier hexadécimal (0xRRGGBB).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension Font {
    /// Police de l'application. Le design vise Manrope ; en son absence on
    /// s'appuie sur la police système, très proche à ces graisses.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Text {
    /// Grand titre : graisse 800 et tracking resserré (-0.03em environ).
    func bigTitle(_ size: CGFloat = 36) -> some View {
        self
            .font(.app(size, .heavy))
            .tracking(size * -0.03)
    }
}
