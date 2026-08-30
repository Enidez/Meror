//
//  TaskFlowViews.swift
//  Enidez
//
//  Le cœur : le tri du matin, l'écran du jour, le focus.
//  Aucune série imposée, aucun tableau de bord. Deux choses à la fois.
//

import SwiftUI

// MARK: - Le tri du matin

struct TriageView: View {
    @Environment(AppModel.self) private var model

    /// Les choses ouvertes, suggestions d'abord.
    private var openItems: [Item] {
        let suggested = Planner.suggestions(from: model.items).map(\.item.id)
        return model.items.filter(\.isOpen).sorted { a, b in
            let sa = suggested.firstIndex(of: a.id) ?? Int.max
            let sb = suggested.firstIndex(of: b.id) ?? Int.max
            if sa != sb { return sa < sb }
            return a.createdAt < b.createdAt
        }
    }

    var body: some View {
        PhoneScreen(time: "6:22", trailing: "mardi 18") {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackButton { model.go(to: .afterCoffee) }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)

                Text("Qu'est-ce qui compte\naujourd'hui ?")
                    .bigTitle(32)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                    .padding(.top, 14)

                Text("J'en ai choisi deux. Change si tu veux.")
                    .font(.app(15, .medium))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 30)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(openItems) { item in
                            row(item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }

                VStack(spacing: 12) {
                    CaptureField(placeholder: "Ajoute une chose — écris ou dicte")
                    PrimaryButton(title: "C'est parti") {
                        model.confirmTriage()
                    }
                    .disabled(model.triagePicks.isEmpty)
                    .opacity(model.triagePicks.isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
    }

    private func row(_ item: Item) -> some View {
        let picked = model.triagePicks.contains(item.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { model.toggleTriage(item.id) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(picked ? Palette.accent : Color.white.opacity(0.18), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if picked {
                        Circle().fill(Palette.accent).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.app(17, .bold))
                        .foregroundStyle(picked ? Palette.textPrimary : Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                    if let reason = model.triageReason(for: item.id) {
                        Text(reason)
                            .font(.app(13, .medium))
                            .foregroundStyle(Palette.accent.opacity(0.85))
                    } else if let estimate = item.estimateLabel {
                        Text(estimate)
                            .font(.app(13, .medium))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(picked ? Palette.surface : Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Aujourd'hui

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
                    if let current = model.currentPick {
                        currentCard(current)
                        if let next = model.nextPick {
                            nextRow(next)
                        }
                        heldLine
                    } else {
                        restingNote(AdviceEngine.restingNote(model.life))
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                CaptureButtons()
                    .padding(.bottom, 20)
            }
        }
    }

    /// « Je garde N autres choses de côté » — touche pour revoir le tri.
    @ViewBuilder
    private var heldLine: some View {
        let count = model.heldItems.count
        if count > 0 {
            Button {
                model.startTriage()
            } label: {
                Text("Je garde \(count) autre\(count > 1 ? "s" : "") chose\(count > 1 ? "s" : "") de côté.")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Palette.sand)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        } else {
            Text("C'est tout pour aujourd'hui.")
                .font(.app(15, .semibold))
                .foregroundStyle(Palette.textMuted)
                .padding(.top, 4)
        }
    }

    /// Affiché quand tout est fait : le mot du jour, calme et fixe.
    private func restingNote(_ note: RestingNote) -> some View {
        VStack(spacing: 16) {
            MerorMark(unit: 6, gap: 10, tint: Palette.accent.opacity(0.65))
                .padding(.bottom, 10)
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

    private func currentCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Circle().fill(Palette.accent).frame(width: 7, height: 7)
                Text("MAINTENANT")
                    .font(.app(12, .bold))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x86868C))
            }
            Text(item.title)
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

    private func nextRow(_ item: Item) -> some View {
        HStack(spacing: 14) {
            Circle()
                .stroke(Palette.sand.opacity(0.55), lineWidth: 2)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.app(18, .bold))
                    .foregroundStyle(Color(hex: 0xD6D6D9))
                Text(item.estimateLabel.map { "\($0) · ensuite" } ?? "ensuite")
                    .font(.app(14, .medium))
                    .foregroundStyle(Palette.sand.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Focus

struct HyperfocusView: View {
    @Environment(AppModel.self) private var model

    private let total = 15 * 60
    @State private var remaining = 15 * 60
    @State private var running = true
    /// La pause : on ne coupe pas l'élan, on l'accompagne quand il s'essouffle.
    @State private var onBreak = false
    /// Combien de pensées existaient au départ : les suivantes sont de ce focus.
    @State private var thoughtsAtStart = 0

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    /// Ce qui a été confié pendant ce focus — à trier pendant la pause.
    private var thoughtsThisSession: [String] {
        Array(model.capturedThoughts.dropFirst(thoughtsAtStart))
    }

    var body: some View {
        PhoneScreen(time: "6:23", trailing: "FOCUS", trailingIsLabel: true) {
            VStack(spacing: 0) {
                HStack {
                    BackButton { model.inFocus = false }
                    Spacer()
                    Text(model.currentPick?.title ?? "")
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
                        model.completeCurrentPick()
                    }
                    HStack(spacing: 12) {
                        pillButton(running ? "Pause" : "Reprendre") { running.toggle() }
                        pillButton("+ 5 min") { remaining += 5 * 60 }
                    }
                }
                .padding(.horizontal, 34)

                Spacer()

                // Rien d'autre : une pensée parasite se confie d'un geste,
                // à la voix ou au clavier.
                HStack(spacing: 14) {
                    MicButton { model.isListening = true }
                    WriteButton { model.isWriting = true }
                }
                .padding(.bottom, 28)
            }
        }
        .overlay {
            if onBreak {
                BreakView(
                    task: model.currentPick,
                    project: model.currentPick?.projectID.flatMap { id in
                        model.projects.first { $0.id == id }
                    },
                    thoughts: thoughtsThisSession,
                    onResume: { minutes in
                        remaining = minutes * 60
                        running = true
                        onBreak = false
                    },
                    onDone: { model.completeCurrentPick() },
                    onStop: { model.inFocus = false },
                    onKeep: { thought in model.capture(thought) }
                )
                .transition(.opacity)
            }
        }
        .onAppear { thoughtsAtStart = model.capturedThoughts.count }
        .task(id: running) {
            while running && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if running { remaining -= 1 }
            }
            // Le temps est écoulé : on ne coupe pas sèchement, on propose
            // la pause. C'est là que le corps et la tête se rattrapent.
            if remaining <= 0 && !onBreak {
                running = false
                withAnimation(.easeInOut(duration: 0.3)) { onBreak = true }
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
