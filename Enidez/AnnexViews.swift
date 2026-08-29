//
//  AnnexViews.swift
//  Enidez
//
//  Écrans secondaires : les jours à venir et « Ton évolution ».
//  Non frontaux : pas de barres, pas de podium, une observation bienveillante.
//

import SwiftUI

// MARK: - 3f · Les jours à venir

struct UpcomingView: View {
    @Environment(AppModel.self) private var model

    private let weekDays = ["L", "M", "M", "J", "V", "S", "D"]

    /// Charge de chaque jour du mois (intensité des points).
    private let busy: [Int: Int] = [3: 1, 6: 2, 10: 1, 13: 2, 18: 3, 19: 1, 21: 1, 24: 2, 27: 1]
    private let today = 18

    var body: some View {
        PhoneScreen(time: "6:22", trailing: "août") {
            VStack(spacing: 0) {
                header

                VStack(spacing: 22) {
                    calendar
                    deadlines
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)

                dictationBar
            }
        }
    }

    private var header: some View {
        HStack {
            Text("À venir").bigTitle(30).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button {
                model.isListening = true
            } label: {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.surface)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.textTertiary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var calendar: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.app(11, .bold))
                    .foregroundStyle(Palette.textGhost)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
            }
            ForEach(0..<35, id: \.self) { index in
                dayCell(day: index - 4)
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let inMonth = day >= 1 && day <= 31
        let isToday = day == today
        let load = busy[day] ?? 0

        VStack(spacing: 4) {
            Text(inMonth ? "\(day)" : "")
                .font(.app(14, .semibold))
                .foregroundStyle(dayColor(day: day, inMonth: inMonth, isToday: isToday))
            Circle()
                .fill(dotColor(load: load, inMonth: inMonth, isToday: isToday))
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isToday ? Color.white.opacity(0.08) : Color.clear)
        )
    }

    private func dayColor(day: Int, inMonth: Bool, isToday: Bool) -> Color {
        if !inMonth { return .clear }
        if isToday { return Palette.textPrimary }
        return day < today ? Palette.textGhost : Palette.textSecondary
    }

    private func dotColor(load: Int, inMonth: Bool, isToday: Bool) -> Color {
        if !inMonth || load == 0 { return .clear }
        if isToday { return Palette.accent }
        return load > 1 ? Color.white.opacity(0.35) : Color.white.opacity(0.16)
    }

    private var deadlines: some View {
        VStack(spacing: 0) {
            ForEach(model.deadlines) { deadline in
                HStack(spacing: 14) {
                    Text(deadline.day)
                        .font(.app(13, .bold))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(width: 54, alignment: .leading)
                    Text(deadline.title)
                        .font(.app(17, .semibold))
                        .foregroundStyle(Color(hex: 0xD6D6D9))
                    Spacer()
                    if deadline.hasAccent {
                        Circle().fill(Palette.accent).frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 16)
                .overlay(alignment: .top) {
                    Rectangle().fill(Palette.separator).frame(height: 1)
                }
            }
        }
    }

    private var dictationBar: some View {
        HStack(spacing: 16) {
            Text("« Jeudi, penser au dentiste » — dicte, je le place.")
                .font(.app(15, .medium))
                .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: 0)
            MicButton { model.isListening = true }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

// MARK: - 3h · Ton évolution

struct EvolutionView: View {
    @Environment(AppModel.self) private var model

    /// Points d'activité d'un mois, reproduits du semis pseudo-aléatoire du design.
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

    var body: some View {
        PhoneScreen(time: "21:40", trailing: "août") {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackButton { model.go(to: .today) }
                    Spacer()
                    Button {
                        model.go(to: .profile)
                    } label: {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.surface)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Palette.textMuted)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)

                Text("Ton évolution")
                    .bigTitle(30)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)

                Spacer()

                VStack(alignment: .leading, spacing: 26) {
                    observation
                    threeMonths
                    adviceCard
                    Text(AdviceEngine.summaryLine(model.life))
                        .font(.app(15, .medium))
                        .foregroundStyle(Palette.textMuted)
                }
                .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 16) {
                    Text("« Pourquoi j'ai décroché hier ? » — demande-moi.")
                        .font(.app(15, .medium))
                        .foregroundStyle(Palette.textTertiary)
                    Spacer(minLength: 0)
                    MicButton { model.isListening = true }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }
        }
    }

    private var observation: some View {
        let parts = AdviceEngine.observation(model.life)
        return (Text(parts.lead + " ")
            + Text(parts.tail).foregroundColor(Palette.textTertiary))
            .font(.app(24, .bold))
            .tracking(-0.5)
            .foregroundStyle(Color(hex: 0xD6D6D9))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var threeMonths: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TROIS DERNIERS MOIS")
                .font(.app(12, .bold))
                .tracking(2)
                .foregroundStyle(Palette.textGhost)
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

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CE QUE JE TE PROPOSE")
                .font(.app(12, .bold))
                .tracking(2)
                .foregroundStyle(Palette.textGhost)
            Text(AdviceEngine.advice(model.life))
                .font(.app(18, .semibold))
                .foregroundStyle(Color(hex: 0xD6D6D9))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { model.go(to: .today) } label: {
                    Text("On essaie")
                        .font(.app(15, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
                Button { model.go(to: .today) } label: {
                    Text("Pas cette fois")
                        .font(.app(15, .semibold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(22)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
