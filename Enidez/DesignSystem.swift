//
//  DesignSystem.swift
//  Enidez
//
//  Palette et typographie de Meror.
//  Encre chaude, un seul niveau d'emphase par écran, deux couleurs qui portent
//  du sens : le citron pour maintenant, le sable pour ce qui attend.
//

import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif

/// Couleurs de Meror.
///
/// Le fond n'est pas le noir par défaut d'iOS mais une **encre chaude** : une
/// base brune très sombre. Elle adoucit le citron — une couleur froide et dure —
/// et donne à l'app un grain reconnaissable sans qu'on ait à lire un mot.
///
/// Deux couleurs portent du sens, jamais de la décoration :
/// le **citron** dit ce qui est maintenant, le **sable** dit ce qui attend.
enum Palette {
    /// Fond des écrans.
    static let screen = Color(hex: 0x070504)
    /// Fond du canevas, à peine au-dessus du fond.
    static let canvas = Color(hex: 0x0F0D0B)

    /// Surfaces pour les cartes secondaires et les boutons ronds.
    static let surface = Color(hex: 0x161312)
    static let surfaceRaised = Color(hex: 0x181413)

    /// Dégradé de la carte mise en avant.
    static let cardTop = Color(hex: 0x2E2823)
    static let cardBottom = Color(hex: 0x1C1816)

    /// Texte : un seul élément actif par écran, le reste s'efface.
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8A8A90)
    static let textTertiary = Color(hex: 0x55555A)
    static let textMuted = Color(hex: 0x6A6A6F)
    static let textFaint = Color(hex: 0x4A4A50)
    static let textGhost = Color(hex: 0x3F3F45)

    /// Citron : ce qui est **maintenant**. Un point de couleur, jamais une surface.
    static let accent = Color(hex: 0xD8FF3E)

    /// Sable : ce qui **attend**, ce qu'on garde de côté.
    static let sand = Color(hex: 0xE0C9A6)
    /// Le même sable, effacé, pour les étiquettes de section.
    static let sandGhost = Color(hex: 0x7A6B57)

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

// MARK: - Typographie

/// La police de Meror. Manrope (SIL OFL) est embarquée : c'est elle qui
/// distingue l'app de tout ce qui se contente de la police système d'Apple.
/// Un seul fichier variable porte toutes les graisses.
enum Typeface {
    /// Enregistre la police auprès du système. À appeler une fois au lancement.
    static func register() {
        guard let url = Bundle.main.url(forResource: "Manrope", withExtension: "ttf") else {
            return   // absente : on retombera sur la police système
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Le nom PostScript de l'instance correspondant à une graisse SwiftUI.
    /// Manrope monte jusqu'à ExtraBold (800) : `.heavy` et `.black` y mènent.
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin: "Manrope-ExtraLight"
        case .light:             "Manrope-Light"
        case .regular:           "Manrope-Regular"
        case .medium:            "Manrope-Medium"
        case .semibold:          "Manrope-SemiBold"
        case .bold:              "Manrope-Bold"
        default:                 "Manrope-ExtraBold"   // .heavy, .black
        }
    }

    /// Vrai si Manrope a bien été chargée (sinon on garde la police système).
    static var isAvailable: Bool {
        UIFont(name: "Manrope-Regular", size: 12) != nil
    }
}

extension Font {
    /// Police de l'application : Manrope, avec repli propre sur la police
    /// système si le fichier venait à manquer.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Typeface.isAvailable
            ? .custom(Typeface.name(for: weight), size: size)
            : .system(size: size, weight: weight)
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
