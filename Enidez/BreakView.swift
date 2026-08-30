//
//  BreakView.swift
//  Enidez
//
//  La pause de l'hyperfocus.
//
//  Pendant le focus, l'app se tait complètement — rien ne doit t'interrompre.
//  Mais l'hyperfocus ne s'arrête pas tout seul, et le corps paie : on ne boit
//  pas, on ne mange pas, on ne se lève pas. Alors quand le temps est écoulé,
//  l'app s'invite une fois, brièvement, et sans reproche.
//
//  Trois choses s'y passent :
//   1. on dit ce qui a été fait, pour de vrai ;
//   2. on trie les pensées confiées pendant le focus — c'est le moment,
//      elles ont attendu là exprès ;
//   3. on choisit la suite, en connaissance de cause.
//

import SwiftUI

struct BreakView: View {
    var task: Item?
    var project: Project?
    var thoughts: [String]
    var onResume: (Int) -> Void      // minutes
    var onDone: () -> Void
    var onStop: () -> Void
    var onKeep: (String) -> Void

    /// Les pensées encore à trier.
    @State private var pending: [String] = []
    @State private var started = false

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                header

                if !pending.isEmpty {
                    thoughtsSection
                        .padding(.top, 30)
                }

                Spacer(minLength: 20)

                actions
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 34)
        }
        .onAppear {
            guard !started else { return }
            started = true
            pending = thoughts
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 18) {
            MerorMark(unit: 6, gap: 10, tint: Palette.accent.opacity(0.7))

            Text("Pause.")
                .bigTitle(34)
                .foregroundStyle(Palette.textPrimary)

            Text(encouragement)
                .font(.app(17, .medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Text("Bois un verre d'eau. Lève-toi une minute.")
                .font(.app(14, .medium))
                .foregroundStyle(Palette.sand.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    /// Un mot lié à ce sur quoi on vient de travailler — jamais générique.
    private var encouragement: String {
        if let project {
            return "Tu viens d'avancer sur \(project.title). C'est exactement comme ça que ça se fait : par morceaux."
        }
        if let task {
            return "Tu viens de passer un vrai quart d'heure sur « \(task.title) ». C'est fait, personne ne peut te l'enlever."
        }
        return "Un quart d'heure de vrai focus. C'est déjà quelque chose."
    }

    // MARK: - Les pensées confiées pendant le focus

    private var thoughtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pending.count > 1
                 ? "\(pending.count) PENSÉES GARDÉES PENDANT"
                 : "UNE PENSÉE GARDÉE PENDANT")
                .font(.app(11, .bold))
                .tracking(2)
                .foregroundStyle(Palette.sandGhost)

            ForEach(pending, id: \.self) { thought in
                HStack(spacing: 12) {
                    Text(thought)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color(hex: 0xD6D6D9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { keep(thought) } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    Button { drop(thought) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.textGhost)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text("Garde ce qui compte, jette le reste. Rien ne se perd sans que tu l'aies décidé.")
                .font(.app(13, .medium))
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func keep(_ thought: String) {
        onKeep(thought)
        withAnimation(.easeInOut(duration: 0.2)) { pending.removeAll { $0 == thought } }
    }

    private func drop(_ thought: String) {
        withAnimation(.easeInOut(duration: 0.2)) { pending.removeAll { $0 == thought } }
    }

    // MARK: - La suite

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Repartir 15 minutes") { onResume(15) }
            HStack(spacing: 12) {
                pill("C'est fait") { onDone() }
                pill("J'arrête là") { onStop() }
            }
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(15, .semibold))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
