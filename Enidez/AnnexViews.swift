//
//  AnnexViews.swift
//  Enidez
//
//  L'onglet « À venir » : le calendrier du mois et les échéances.
//

import SwiftUI

// MARK: - Onglet · À venir

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
        HStack(spacing: 14) {
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
