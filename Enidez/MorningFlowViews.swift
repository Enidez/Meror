//
//  MorningFlowViews.swift
//  Enidez
//
//  Le début du parcours : bienvenue, réveil, pause café, relance.
//  L'assistant parle, l'utilisateur répond — à la voix ou d'un geste.
//

import SwiftUI

// MARK: - 3i · Bienvenue

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    /// Diagonale de points, comme le logo des maquettes.
    private let logoDots: [Double] = [0.9, 0.2, 0.2, 0.2, 0.9, 0.2, 0.2, 0.2, 0.9]

    var body: some View {
        PhoneScreen(time: "9:41", trailing: "v1") {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    logo
                    VStack(spacing: 12) {
                        Text("Un jour")
                            .font(.app(44, .heavy))
                            .tracking(-1.7)
                            .foregroundStyle(Palette.textPrimary)
                        Text("Un moment à la fois.")
                            .font(.app(18, .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Commencer", height: 60) {
                        model.go(to: .onboarding)
                    }

                    Button {
                        model.go(to: .onboarding)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 17, weight: .medium))
                            Text("Continuer avec Apple")
                                .font(.app(17, .bold))
                        }
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: 0x131316), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("En continuant, tu acceptes nos conditions et notre politique de confidentialité.")
                        .font(.app(12, .medium))
                        .foregroundStyle(Palette.textFaint)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
    }

    private var logo: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x232327), Palette.surface],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 120, height: 120)
            .overlay(
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(11), spacing: 9), count: 3), spacing: 9) {
                    ForEach(Array(logoDots.enumerated()), id: \.offset) { _, opacity in
                        Circle()
                            .fill(Color.white.opacity(opacity))
                            .frame(width: 11, height: 11)
                    }
                }
                .fixedSize()
            )
    }
}

// MARK: - Premier lancement · Ton prénom

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        PhoneScreen(time: "9:41", trailing: "v1") {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 26) {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 8, height: 8)

                    (Text("Comment on\n")
                        + Text("t'appelle ?").foregroundColor(Palette.textSecondary))
                        .bigTitle(36)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("", text: $name, prompt: Text("Ton prénom").foregroundColor(Palette.textFaint))
                        .font(.app(28, .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(Palette.textPrimary)
                        .tint(Palette.accent)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit(save)
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(focused ? Palette.accent : Palette.hairline)
                                .frame(height: 2)
                        }

                    Text("Juste pour te parler comme il faut. Ça reste sur ton téléphone.")
                        .font(.app(15, .medium))
                        .foregroundStyle(Palette.textTertiary)
                        .lineSpacing(4)
                }

                Spacer()

                PrimaryButton(title: "C'est parti") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 20)
        }
        .onAppear { focused = true }
    }

    private func save() {
        model.completeOnboarding(name: name)
    }
}

// MARK: - Premier lancement · Trois questions pour te cerner

struct AttuneView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var energy: EnergyMoment?
    @State private var struggle: DailyStruggle?
    @State private var good: GoodDay?

    var body: some View {
        PhoneScreen(time: "9:41", trailing: "v1") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Palette.accent : Color.white.opacity(0.12))
                            .frame(width: i == step ? 24 : 7, height: 4)
                    }
                }
                .padding(.top, 32)
                .animation(.easeInOut(duration: 0.2), value: step)

                Spacer()

                question
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))

                Spacer()
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var question: some View {
        switch step {
        case 0:
            block(lead: "À quel moment tu\n", tail: "tiens le mieux ?",
                  hint: "Ton énergie, ta tête claire.") {
                ForEach(EnergyMoment.allCases) { option in
                    choice(option.rawValue, selected: energy == option) {
                        energy = option; advance()
                    }
                }
            }
        case 1:
            block(lead: "Qu'est-ce qui te\n", tail: "complique les journées ?",
                  hint: "Sans jugement. Juste pour t'aider comme il faut.") {
                ForEach(DailyStruggle.allCases) { option in
                    choice(option.rawValue, selected: struggle == option) {
                        struggle = option; advance()
                    }
                }
            }
        default:
            block(lead: "Une bonne journée\n", tail: "pour toi, c'est…",
                  hint: "Ce qui te laisse le cœur léger, le soir.") {
                ForEach(GoodDay.allCases) { option in
                    choice(option.rawValue, selected: good == option) {
                        good = option; finish()
                    }
                }
            }
        }
    }

    private func block<Options: View>(lead: String, tail: String, hint: String,
                                      @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Circle().fill(Palette.accent).frame(width: 8, height: 8)

            (Text(lead) + Text(tail).foregroundColor(Palette.textSecondary))
                .bigTitle(32)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(hint)
                .font(.app(15, .medium))
                .foregroundStyle(Palette.textTertiary)
                .lineSpacing(4)

            VStack(spacing: 10) {
                options()
            }
            .padding(.top, 6)
        }
    }

    private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.app(16, .semibold))
                    .foregroundStyle(selected ? .black : Palette.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(selected ? Palette.accent : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
    }

    private func finish() {
        guard let energy, let struggle, let good else { return }
        model.completeAttune(energy: energy, struggle: struggle, goodDay: good)
    }
}

// MARK: - 3a · Le réveil

struct WakeUpView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PhoneScreen(time: "6:15", trailing: "mardi 18") {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 26) {
                    (Text("Bonjour \(model.name).\n")
                        + Text("Tu as bien dormi ?").foregroundColor(Palette.textSecondary))
                        .bigTitle(36)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(AdviceEngine.wakeUpSubtitle(model.life))
                        .font(.app(17, .medium))
                        .foregroundStyle(Palette.textTertiary)
                        .lineSpacing(4)
                }

                Spacer()

                VStack(spacing: 14) {
                    PrimaryButton(title: "Aller prendre un café") {
                        model.go(to: .coffeeBreak)
                    }
                    SecondaryLink(title: "Encore 10 minutes") {
                        model.go(to: .coffeeBreak)
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - 3b · La pause café

struct CoffeeBreakView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PhoneScreen(time: "6:16", trailing: "mardi 18") {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 34) {
                    HourglassView()
                    Text("à tout de suite")
                        .font(.app(19, .medium))
                        .italic()
                        .foregroundStyle(Palette.textTertiary)
                }

                Spacer()

                Text("Passer la pause")
                    .font(.app(15, .semibold))
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { model.go(to: .afterCoffee) }
                    .padding(.bottom, 8)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.go(to: .afterCoffee) }
        }
    }
}

// MARK: - 3c · Après le café

struct AfterCoffeeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PhoneScreen(time: "6:21", trailing: "mardi 18") {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 22) {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 8, height: 8)

                    (Text("\(model.name), on regarde ce qui\n")
                        + Text("compte aujourd'hui.").foregroundColor(Palette.textSecondary))
                        .bigTitle(36)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                PrimaryButton(title: "On y va") {
                    model.startTriage()
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 20)
        }
    }
}
