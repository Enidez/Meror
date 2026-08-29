//
//  Components.swift
//  Enidez
//
//  Briques d'interface partagées par tous les écrans.
//  Le bouton micro est présent partout : la voix est l'entrée principale.
//

import SwiftUI

// MARK: - Ossature d'écran

/// Enveloppe commune : fond noir, bandeau contextuel en haut, contenu au centre.
/// Sur appareil, l'iPhone fournit lui-même la barre d'état et l'indicateur
/// d'accueil — on ne les redessine pas.
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

// MARK: - Saisie : écrire ou dicter

/// Un endroit fixe pour donner quelque chose à l'assistant — au clavier ou
/// à la voix. La voix reste là (icône micro), mais on n'y est jamais obligé.
struct CaptureField: View {
    var placeholder: String

    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .font(.app(15, .medium))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.accent)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(send)

            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    focused = false
                    model.isListening = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 34, height: 34)
                        .background(Palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 54)
        .background(Palette.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Palette.hairline, lineWidth: 1))
    }

    private func send() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        focused = false
        guard !value.isEmpty else { return }
        model.capture(value)
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

// MARK: - L'attente (pause café)

/// Le temps qui passe, dans la langue de Meror : la marque à neuf points,
/// et une lumière verte qui descend la diagonale, encore et encore. Calme,
/// sans compte à rebours.
struct PauseMark: View {
    private let unit: CGFloat = 13
    private let gap: CGFloat = 22

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle = 3.4
            let phase = t.truncatingRemainder(dividingBy: cycle) / cycle
            // Descente sur 70 % du cycle, repos sombre sur le reste.
            let travel = phase > 0.7 ? -1 : min(phase / 0.7, 1.0)

            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<3, id: \.self) { col in
                            dot(onDiagonal: row == col, center: Double(row) / 2, travel: travel)
                        }
                    }
                }
            }
        }
        .frame(width: unit * 3 + gap * 2, height: unit * 3 + gap * 2)
    }

    private func dot(onDiagonal: Bool, center: Double, travel: Double) -> some View {
        let glow = (travel < 0 || !onDiagonal)
            ? 0.0
            : max(0, 1 - abs(travel - center) * 3.2)

        return Circle()
            .fill(Color.white.opacity(0.12))
            .overlay(Circle().fill(Palette.accent).opacity(glow))
            .frame(width: unit, height: unit)
            .scaleEffect(1 + glow * 0.55)
            .shadow(color: Palette.accent.opacity(glow * 0.5), radius: glow * 9)
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
