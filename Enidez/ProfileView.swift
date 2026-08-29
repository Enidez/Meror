//
//  ProfileView.swift
//  Enidez
//
//  L'onglet « Toi » : ce que l'assistant sait de toi, et comment tu évolues.
//  Une observation bienveillante en ouverture, puis l'humeur, le sommeil,
//  l'activité, le rythme, les trois derniers mois, un conseil, l'objectif de
//  coucher. Jamais de score, jamais de reproche.
//

import SwiftUI

struct YouView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        PhoneScreen(time: "6:24", trailing: "toi") {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        observation
                            .padding(.bottom, 4)
                        moodSection
                        sleepSection
                        activitySection
                        focusSection
                        threeMonths
                        adviceCard
                        bedtimeSection($model.life.targetBedtime)
                        connectionNote
                        Text(AdviceEngine.summaryLine(model.life))
                            .font(.app(14, .medium))
                            .foregroundStyle(Palette.textMuted)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack {
            Text("Toi").bigTitle(30).foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    // MARK: - Observation d'ouverture

    private var observation: some View {
        let parts = AdviceEngine.observation(model.life)
        return (Text(parts.lead + " ")
            + Text(parts.tail).foregroundColor(Palette.textTertiary))
            .font(.app(22, .bold))
            .tracking(-0.4)
            .foregroundStyle(Color(hex: 0xD6D6D9))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Humeur

    private var moodSection: some View {
        Card {
            Text("COMMENT TU TE SENS").sectionLabel()
            HStack(spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    moodChip(mood)
                }
            }
        }
    }

    private func moodChip(_ mood: Mood) -> some View {
        let selected = model.life.lastMood == mood
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { model.record(mood: mood) }
        } label: {
            Text(mood.rawValue)
                .font(.app(15, .semibold))
                .foregroundStyle(selected ? .black : Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(selected ? Palette.accent : Color.white.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sommeil

    private var sleepSection: some View {
        Card {
            Text("SOMMEIL").sectionLabel()
            metric("Cette nuit", value: model.life.lastNightSleepHours.map(AdviceEngine.hours) ?? "—")
            metric("Moyenne", value: model.life.averageSleepHours.map(AdviceEngine.hours) ?? "—")
            if let bedtime = model.life.averageBedtime {
                metric("Coucher", value: AdviceEngine.clock(bedtime))
            }
        }
    }

    // MARK: - Activité

    private var activitySection: some View {
        Card {
            Text("ACTIVITÉ AUJOURD'HUI").sectionLabel()
            metric("Pas", value: model.life.stepsToday.map { "\($0)" } ?? "—")
            metric("Énergie", value: model.life.activeEnergyToday.map { "\(Int($0)) kcal" } ?? "—")
        }
    }

    // MARK: - Focus

    private var focusSection: some View {
        Card {
            Text("TON RYTHME").sectionLabel()
            metric("Meilleur moment", value: model.life.bestFocusPeriod.label)
            metric("Régularité", value: "\(model.life.focusStreakDays) jours")
        }
    }

    // MARK: - Trois derniers mois

    private func seedDots(count: Int, density: Double, seed: Double) -> [Double] {
        (0..<count).map { i in
            let raw = sin(Double(i) * 12.9898 + seed) * 43758.5453
            let v = abs(raw.truncatingRemainder(dividingBy: 1))
            if v < density { return v < density * 0.35 ? 0.75 : 0.4 }
            return 0.1
        }
    }

    private var months: [(label: String, dots: [Double])] {
        [
            ("Juin", seedDots(count: 28, density: 0.5, seed: 3)),
            ("Juil", seedDots(count: 28, density: 0.68, seed: 9)),
            ("Août", seedDots(count: 28, density: 0.6, seed: 17))
        ]
    }

    private var threeMonths: some View {
        Card {
            Text("TROIS DERNIERS MOIS").sectionLabel()
            HStack(alignment: .top, spacing: 16) {
                ForEach(months, id: \.label) { month in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(month.label)
                            .font(.app(13, .semibold))
                            .foregroundStyle(Palette.textTertiary)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(5), spacing: 5), count: 7), spacing: 5) {
                            ForEach(Array(month.dots.enumerated()), id: \.offset) { _, opacity in
                                Circle()
                                    .fill(Color.white.opacity(opacity))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Conseil

    private var adviceCard: some View {
        Card {
            Text("CE QUE JE TE PROPOSE").sectionLabel()
            Text(AdviceEngine.advice(model.life))
                .font(.app(17, .semibold))
                .foregroundStyle(Color(hex: 0xD6D6D9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Objectif de coucher

    private func bedtimeSection(_ binding: Binding<Date>) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OBJECTIF DE COUCHER").sectionLabel()
                    Text("Je m'appuie dessus pour te conseiller.")
                        .font(.app(13, .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Palette.accent)
            }
        }
    }

    // MARK: - État de la connexion Santé

    @ViewBuilder
    private var connectionNote: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.life.healthConnected ? Palette.accent : Palette.textGhost)
                .frame(width: 7, height: 7)
            Text(model.life.healthConnected
                 ? "Apple Santé connecté."
                 : "Connecte Apple Santé pour des conseils sur mesure.")
                .font(.app(14, .medium))
                .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: - Lignes de mesure

    private func metric(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.app(16, .medium))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.app(16, .bold))
                .foregroundStyle(Palette.textPrimary)
        }
    }
}

// MARK: - Carte de section

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private extension Text {
    /// Étiquette de section : petite, espacée, très effacée.
    func sectionLabel() -> some View {
        self.font(.app(12, .bold))
            .tracking(2)
            .foregroundStyle(Palette.textGhost)
    }
}
