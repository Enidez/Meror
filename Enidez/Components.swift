//
//  Components.swift
//  Enidez
//
//  Briques d'interface partagées par tous les écrans.
//  Le bouton micro est présent partout : la voix est l'entrée principale.
//

import SwiftUI

// MARK: - Ossature d'écran

/// Enveloppe commune : fond noir, barre d'état en haut, contenu au centre,
/// indicateur d'accueil en bas. Reproduit le cadre des maquettes.
struct PhoneScreen<Content: View>: View {
    var time: String
    var trailing: String
    var trailingIsLabel: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            StatusBar(time: time, trailing: trailing, trailingIsLabel: trailingIsLabel)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HomeIndicator()
        }
        .background(Palette.screen.ignoresSafeArea())
    }
}

/// Barre du haut : l'heure à gauche, la date (ou une étiquette) à droite.
struct StatusBar: View {
    var time: String
    var trailing: String
    var trailingIsLabel: Bool = false

    var body: some View {
        HStack {
            Text(time)
                .font(.app(15, .bold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            if trailingIsLabel {
                Text(trailing)
                    .font(.app(12, .bold))
                    .tracking(2)
                    .foregroundStyle(Palette.textGhost)
            } else {
                Text(trailing)
                    .font(.app(13, .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.3))
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
    }
}

/// Le petit trait d'accueil au bas de l'écran.
struct HomeIndicator: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 130, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
    }
}

// MARK: - Boutons

/// Le bouton micro, rond et sombre, avec un trait d'accent.
/// On appuie, on parle, ça s'arrête quand on a fini.
struct MicButton: View {
    var size: CGFloat = 54
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Palette.surfaceRaised)
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "mic")
                        .font(.system(size: size * 0.36, weight: .regular))
                        .foregroundStyle(Palette.accent)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Bouton principal pleine largeur, blanc, texte noir.
struct PrimaryButton: View {
    var title: String
    var height: CGFloat = 62
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(17, .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Ligne d'action secondaire, discrète et centrée.
struct SecondaryLink: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(15, .semibold))
                .foregroundStyle(Palette.textFaint)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Bouton rond avec un chevron « retour ».
struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Retour d'écoute du micro

/// Voile d'écoute affiché quand l'assistant capte la voix.
struct ListeningOverlay: View {
    var name: String
    var transcript: String = ""
    var status: SpeechService.Status = .listening
    var onDone: () -> Void

    @State private var pulse = false

    /// Message sous le titre : le texte en cours, ou un repli si la dictée
    /// n'est pas disponible.
    private var hint: String {
        if !transcript.isEmpty { return transcript }
        switch status {
        case .denied:      return "Micro refusé. Réglages → Enidez pour l'autoriser."
        case .unavailable: return "La dictée n'est pas disponible ici. Note au doigt."
        default:           return "Parle, je note."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 32) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0.15 : 1)
                    .overlay(
                        Circle().fill(Palette.accent).frame(width: 14, height: 14)
                    )
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)

                Text("Je t'écoute, \(name).")
                    .font(.app(24, .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.textPrimary)

                Text(hint)
                    .font(.app(transcript.isEmpty ? 16 : 20, transcript.isEmpty ? .medium : .semibold))
                    .foregroundStyle(transcript.isEmpty ? Palette.textTertiary : Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .animation(.easeOut(duration: 0.15), value: transcript)
            }
            .padding(.bottom, 40)

            VStack {
                Spacer()
                Button(action: onDone) {
                    Text("Terminé")
                        .font(.app(16, .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 34)
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulse = true }
        .transition(.opacity)
    }
}

// MARK: - Sablier (3b)

/// Sablier stylisé : un X fermé en haut et en bas, du sable qui s'écoule.
struct HourglassView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2

            ZStack {
                // Sable restant, en haut (léger).
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.31))
                    p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.31))
                    p.addLine(to: CGPoint(x: cx, y: cy))
                    p.closeSubpath()
                }
                .fill(Palette.hourglass.opacity(0.3))

                // Sable écoulé, en bas (dense).
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.93))
                    p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.93))
                    p.addLine(to: CGPoint(x: cx, y: h * 0.69))
                    p.closeSubpath()
                }
                .fill(Palette.hourglass.opacity(0.85))

                // Le filet de sable au centre.
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: cx, y: h * 0.74))
                }
                .stroke(Palette.hourglass.opacity(0.55), style: .init(lineWidth: 1.6, lineCap: .round))

                // Le cadre : barres haut/bas et le X.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.13, y: h * 0.06))
                    p.addLine(to: CGPoint(x: w * 0.87, y: h * 0.06))
                    p.move(to: CGPoint(x: w * 0.13, y: h * 0.94))
                    p.addLine(to: CGPoint(x: w * 0.87, y: h * 0.94))

                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.07))
                    p.addLine(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.07))
                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.93))
                    p.addLine(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.93))
                }
                .stroke(Color.white.opacity(0.3), style: .init(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 110, height: 154)
    }
}

// MARK: - Anneau de focus (3g)

/// Anneau fin de progression du focus.
struct FocusRing: View {
    /// Fraction restante, de 1 (plein) à 0 (écoulé).
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.accent, style: .init(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)
        }
    }
}
