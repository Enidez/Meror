//
//  ProfileView.swift
//  Enidez
//
//  Le petit profil : ce que l'assistant sait de toi, sans jamais te noter.
//  Sommeil et activité viennent d'Apple Santé ; l'humeur et l'objectif de
//  coucher se règlent ici, en un geste ou à la voix.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        PhoneScreen(time: "6:24", trailing: "toi") {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        moodSection
                        sleepSection
                        activitySection
                        focusSection
                        bedtimeSection($model.life.targetBedtime)
                        connectionNote
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
            BackButton { model.go(to: .today) }
            Spacer()
        }
        .overlay(
            Text("Toi").bigTitle(30).foregroundStyle(Palette.textPrimary)
        )
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 20)
    }

    // MARK: - Humeur

    private var moodSection: some View {
        Card {
            Text("COMMENT TU TE SENS")
                .sectionLabel()
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
