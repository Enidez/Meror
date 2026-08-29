//
//  TaskFlowViews.swift
//  Enidez
//
//  Le cœur du parcours : les deux choses, l'écran du jour, l'hyperfocus.
//  Aucune série, aucun compteur, aucun reste-à-faire. Une chose à la fois.
//

import SwiftUI

// MARK: - 3d · Les deux choses

struct TwoThingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PhoneScreen(time: "6:21", trailing: "mardi 18") {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackButton { model.go(to: .afterCoffee) }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)

                Spacer()

                VStack(alignment: .leading, spacing: 40) {
                    VStack(alignment: .leading, spacing: 34) {
                        ForEach(Array(model.tasks.enumerated()), id: \.element.id) { index, task in
                            thing(task, active: index == 0)
                        }
                    }
                    Text("Le reste du jour attend. Je le garde de côté.")
                        .font(.app(16, .medium))
                        .foregroundStyle(Palette.textFaint)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 34)

                Spacer()

                VStack(spacing: 14) {
                    PrimaryButton(title: "Je les fais maintenant") {
                        model.enterApp()
                    }
                    CaptureField(placeholder: "Changer une des deux — écris ou dicte")
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 20)
            }
        }
    }

    private func thing(_ task: DayTask, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(active ? Palette.accent : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
                .padding(.top, 13)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.app(30, .heavy))
                    .tracking(-0.9)
                    .foregroundStyle(active ? Palette.textPrimary : Palette.textSecondary)
                Text("\(task.minutes) min")
                    .font(.app(15, .medium))
                    .foregroundStyle(active ? Palette.textMuted : Palette.textTertiary)
            }
        }
    }
}

// MARK: - 3e · Aujourd'hui

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PhoneScreen(time: "6:22", trailing: "mardi 18") {
            VStack(spacing: 0) {
                HStack {
                    Text("Aujourd'hui").bigTitle(34).foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 16) {
                    if let current = model.currentTask {
                        currentCard(current)
                        if let next = model.nextTask {
                            nextRow(next)
                        }
                        Text("C'est tout pour aujourd'hui.")
                            .font(.app(15, .semibold))
                            .foregroundStyle(Palette.textMuted)
                            .padding(.top, 4)
                    } else {
                        restingNote(AdviceEngine.restingNote(model.life))
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                CaptureField(placeholder: "Écris ou dicte une chose à faire")
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
            }
        }
    }

    /// Affiché quand tout est fait : le mot du jour, calme et fixe.
    private func restingNote(_ note: RestingNote) -> some View {
        VStack(spacing: 16) {
            if let label = note.label {
                Text(label)
                    .font(.app(12, .bold))
                    .tracking(2)
                    .foregroundStyle(Palette.textGhost)
            }
            Text(note.text)
                .font(.app(22, .bold))
                .tracking(-0.4)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote = note.footnote {
                Text(footnote)
                    .font(.app(14, .medium))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 20)
    }

    private func currentCard(_ task: DayTask) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Circle().fill(Palette.accent).frame(width: 7, height: 7)
                Text("MAINTENANT")
                    .font(.app(12, .bold))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x86868C))
            }
            Text(task.title)
                .font(.app(26, .heavy))
                .tracking(-0.65)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Démarrer le focus", height: 56) {
                model.inFocus = true
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Palette.cardTop, Palette.cardBottom],
                           startPoint: .topTrailing, endPoint: .bottomLeading),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }

    private func nextRow(_ task: DayTask) -> some View {
        HStack(spacing: 14) {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.app(18, .bold))
                    .foregroundStyle(Color(hex: 0xD6D6D9))
                Text("\(task.minutes) min · ensuite")
                    .font(.app(14, .medium))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - 3g · Hyperfocus

struct HyperfocusView: View {
    @Environment(AppModel.self) private var model

    private let total = 15 * 60
    @State private var remaining = 15 * 60
    @State private var running = true

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        PhoneScreen(time: "6:23", trailing: "FOCUS", trailingIsLabel: true) {
            VStack(spacing: 0) {
                HStack {
                    BackButton { model.inFocus = false }
                    Spacer()
                    Text(model.currentTask?.title ?? "")
                        .font(.app(13, .semibold))
                        .foregroundStyle(Palette.textGhost)
                }
                .padding(.horizontal, 28)
                .padding(.top, 26)

                Spacer()

                ZStack {
                    FocusRing(progress: Double(remaining) / Double(total))
                        .frame(width: 252, height: 252)
                    Text(timeString)
                        .font(.app(62, .heavy))
                        .tracking(-2.8)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "C'est fait") {
                        model.completeCurrentTask()
                    }
                    HStack(spacing: 12) {
                        pillButton(running ? "Pause" : "Reprendre") { running.toggle() }
                        pillButton("+ 5 min") { remaining += 5 * 60 }
                    }
                }
                .padding(.horizontal, 34)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Une pensée parasite ? Note-la, je la garde.")
                        .font(.app(14, .medium))
                        .foregroundStyle(Palette.textTertiary)
                    CaptureField(placeholder: "Écris ou dicte la pensée")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }
        }
        .task(id: running) {
            // Compte à rebours en async/await, sans Combine.
            while running && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if running { remaining -= 1 }
            }
        }
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
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
