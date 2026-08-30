//
//  AnnexViews.swift
//  Enidez
//
//  L'onglet « À venir » : un vrai calendrier. On navigue de mois en mois,
//  on touche un jour pour voir — et pour y poser quelque chose.
//

import SwiftUI

// MARK: - Onglet · À venir

struct UpcomingView: View {
    @Environment(AppModel.self) private var model

    /// N'importe quelle date du mois affiché.
    @State private var monthAnchor = Date()
    /// Le jour touché, ou `nil` pour la liste de ce qui arrive.
    @State private var selectedDay: Date?

    private let weekDays = ["L", "M", "M", "J", "V", "S", "D"]
    private var cal: Calendar { Calendar.current }

    var body: some View {
        PhoneScreen(time: "6:22", trailing: shortMonth) {
            VStack(spacing: 0) {
                header

                calendar
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)

                Divider().overlay(Palette.separator).padding(.horizontal, 28)

                ScrollView(showsIndicators: false) {
                    list
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                }

                CaptureField(placeholder: capturePlaceholder, dueDay: selectedDay)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 44)   // dégage la barre d'onglets flottante
            }
        }
    }

    // MARK: - En-tête et navigation

    private var header: some View {
        HStack(spacing: 0) {
            Text("À venir").bigTitle(30).foregroundStyle(Palette.textPrimary)
            Spacer()
            arrow("chevron.left") { shiftMonth(-1) }
            Text(monthLabel)
                .font(.app(15, .semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(minWidth: 104)
                .contentTransition(.opacity)
            arrow("chevron.right") { shiftMonth(1) }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private func arrow(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 32, height: 32)
                .background(Palette.surface, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            monthAnchor = cal.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
            selectedDay = nil
        }
    }

    // MARK: - La grille

    /// Les cases du mois, alignées lundi en premier. `nil` = case vide.
    private var gridDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let first = interval.start
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = (cal.component(.weekday, from: first) + 5) % 7  // lundi = 0

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<count {
            cells.append(cal.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var calendar: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.app(11, .bold))
                    .foregroundStyle(Palette.textGhost)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
            }
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day) } else { Color.clear.frame(height: 44) }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let count = items(on: day).count
        let isToday = cal.isDateInToday(day)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isPast = day < cal.startOfDay(for: Date())

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDay = isSelected ? nil : day
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.app(14, isToday ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .black
                                     : isToday ? Palette.textPrimary
                                     : isPast ? Palette.textGhost : Palette.textSecondary)
                Circle()
                    .fill(count == 0 ? .clear
                          : isSelected ? .black
                          : isToday ? Palette.accent
                          : Color.white.opacity(count > 1 ? 0.45 : 0.22))
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Palette.accent
                          : isToday ? Color.white.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ce qu'il y a

    /// Les choses ouvertes dont l'échéance tombe ce jour-là.
    private func items(on day: Date) -> [Item] {
        model.items.filter { item in
            guard item.isOpen, let due = item.due else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    /// Les prochaines échéances, à partir d'aujourd'hui.
    private var upcoming: [Item] {
        let today = cal.startOfDay(for: Date())
        return model.items
            .filter { $0.isOpen && ($0.due ?? .distantPast) >= today }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    @ViewBuilder
    private var list: some View {
        let shown = selectedDay.map(items(on:)) ?? upcoming

        VStack(alignment: .leading, spacing: 0) {
            Text(selectedDay.map(longDay) ?? "PROCHAINEMENT")
                .font(.app(12, .bold))
                .tracking(2)
                .foregroundStyle(Palette.textGhost)
                .padding(.bottom, 6)

            if shown.isEmpty {
                Text(selectedDay == nil
                     ? "Rien de daté pour l'instant."
                     : "Rien ce jour-là. Ajoute quelque chose en bas.")
                    .font(.app(15, .medium))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 14)
            } else {
                ForEach(shown) { item in
                    row(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 14) {
            Text(item.due.map(VoiceInterpreter.shortLabel) ?? "")
                .font(.app(13, .bold))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 58, alignment: .leading)
            Text(item.title)
                .font(.app(17, .semibold))
                .foregroundStyle(Color(hex: 0xD6D6D9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let due = item.due, cal.isDateInToday(due) || cal.isDateInTomorrow(due) {
                Circle().fill(Palette.accent).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 15)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.separator).frame(height: 1)
        }
    }

    // MARK: - Mise en forme

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = cal.isDate(monthAnchor, equalTo: Date(), toGranularity: .year)
            ? "LLLL" : "LLLL yyyy"
        return f.string(from: monthAnchor).capitalized
    }

    private var shortMonth: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "LLL"
        return f.string(from: monthAnchor)
    }

    private func longDay(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: day).uppercased()
    }

    private var capturePlaceholder: String {
        selectedDay == nil
            ? "« Jeudi, dentiste » — écris ou dicte"
            : "Ajoute à ce jour — écris ou dicte"
    }
}
