//
//  ProjectViews.swift
//  Enidez
//
//  Un projet, c'est une chose trop grosse pour tenir dans une journée.
//  Le blocage devant elle n'est pas un manque de volonté : c'est que rien
//  n'est assez petit pour être commencé.
//
//  Donc l'app ne demande jamais « fais ce projet ». Elle demande de le
//  découper une fois, puis elle n'en ressort **qu'une marche à la fois**.
//  On ne revoit jamais le bloc entier.
//

import SwiftUI

// MARK: - Créer un projet

struct NewProjectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var why = ""
    @State private var hasDue = true
    @State private var due = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var steps = ""
    @FocusState private var focus: Field?

    private enum Field { case title, why, steps }

    private var stepLines: [String] {
        steps.split(separator: "\n").map(String.init)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !stepLines.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        intro
                        field("CE QUE C'EST", placeholder: "Album photo — mariage Camille",
                              text: $title, focused: .title)
                        field("POUR QUI, POURQUOI", placeholder: "Ce qu'on se rappelle quand on n'a plus envie",
                              text: $why, focused: .why)
                        deadline
                        stepsField
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 22)
                }
            }
            .navigationTitle("Un projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.screen, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Palette.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { save() }
                        .foregroundStyle(canSave ? Palette.accent : Palette.textGhost)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        Text("Découpe-le une fois. Ensuite tu ne verras plus que la marche suivante.")
            .font(.app(16, .medium))
            .foregroundStyle(Palette.textSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ label: String, placeholder: String,
                       text: Binding<String>, focused: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.app(12, .bold)).tracking(2)
                .foregroundStyle(Palette.textGhost)
            TextField("", text: text,
                      prompt: Text(placeholder).foregroundColor(Palette.textFaint),
                      axis: .vertical)
                .lineLimit(1...3)
                .font(.app(18, .semibold))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.accent)
                .focused($focus, equals: focused)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(focus == focused ? Palette.accent : Palette.hairline)
                        .frame(height: 2)
                }
        }
    }

    private var deadline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("POUR QUAND")
                    .font(.app(12, .bold)).tracking(2)
                    .foregroundStyle(Palette.textGhost)
                Spacer()
                Toggle("", isOn: $hasDue).labelsHidden().tint(Palette.accent)
            }
            if hasDue {
                DatePicker("", selection: $due, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Palette.accent)
            }
        }
    }

    private var stepsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LES MARCHES — UNE PAR LIGNE")
                .font(.app(12, .bold)).tracking(2)
                .foregroundStyle(Palette.textGhost)

            Text("La première doit être si petite qu'elle ne se refuse pas. « Ouvrir le dossier » est une marche valable.")
                .font(.app(13, .medium))
                .foregroundStyle(Palette.sand.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            TextField("", text: $steps,
                      prompt: Text("Ouvrir le dossier\nTrier les photos ratées\nChoisir les 40 gardées\n…")
                        .foregroundColor(Palette.textFaint),
                      axis: .vertical)
                .lineLimit(6...14)
                .font(.app(16, .medium))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.accent)
                .focused($focus, equals: .steps)
                .padding(14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focus == .steps ? Palette.accent.opacity(0.5) : Palette.hairline, lineWidth: 1))

            if !stepLines.isEmpty {
                Text("\(stepLines.count) marche\(stepLines.count > 1 ? "s" : "") — tu n'en verras qu'une à la fois.")
                    .font(.app(13, .semibold))
                    .foregroundStyle(Palette.sand)
            }
        }
    }

    private func save() {
        model.addProject(title: title, why: why, due: hasDue ? due : nil, steps: stepLines)
        dismiss()
    }
}

// MARK: - Les projets en cours

/// Une ligne par projet : sa marche suivante, et rien d'autre du bloc.
struct ProjectRow: View {
    @Environment(AppModel.self) private var model
    var project: Project

    var body: some View {
        let p = model.progress(of: project)
        let next = model.nextStep(of: project)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(project.title)
                    .font(.app(17, .bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
                if let due = project.due {
                    Text(VoiceInterpreter.shortLabel(due))
                        .font(.app(12, .bold))
                        .foregroundStyle(urgent(due) ? Palette.accent : Palette.textTertiary)
                }
            }

            if let next {
                HStack(spacing: 10) {
                    Circle().fill(Palette.accent).frame(width: 6, height: 6)
                    Text(next.title)
                        .font(.app(15, .medium))
                        .foregroundStyle(Color(hex: 0xD6D6D9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            } else {
                Text("Toutes les marches sont faites.")
                    .font(.app(15, .medium))
                    .foregroundStyle(Palette.sand)
            }

            progressBar(done: p.done, total: p.total)
        }
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func urgent(_ due: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 99
        return days <= 3
    }

    private func progressBar(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(Palette.sand)
                        .frame(width: total == 0 ? 0 : geo.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 4)
            Text("\(done) sur \(total)")
                .font(.app(12, .medium))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
