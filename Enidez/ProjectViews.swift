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

// MARK: - Un projet, en entier

/// Le seul endroit où l'on voit le bloc complet — et on y vient **exprès**.
/// Le quotidien continue de ne montrer qu'une marche ; ici on fait le point :
/// où j'en suis, quand ça arrivera vraiment, et depuis quand la personne qui
/// attend n'a pas eu de nouvelles.
struct ProjectDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var project: Project

    @State private var newStep = ""
    @FocusState private var addingStep: Bool

    /// On relit depuis le modèle : la copie passée peut dater.
    private var live: Project {
        model.projects.first { $0.id == project.id } ?? project
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        heading
                        forecastCard
                        silenceCard
                        stepsSection
                        addStepField
                        archiveButton
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Le projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.screen, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - En-tête

    private var heading: some View {
        let p = model.progress(of: live)
        return VStack(alignment: .leading, spacing: 10) {
            Text(live.title)
                .bigTitle(30)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !live.why.isEmpty {
                Text(live.why)
                    .font(.app(15, .medium))
                    .foregroundStyle(Palette.sand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Text("\(p.done) marche\(p.done > 1 ? "s" : "") sur \(p.total)")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Palette.textTertiary)
                if let due = live.due {
                    Text("· annoncé pour le \(longDate(due))")
                        .font(.app(14, .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    // MARK: - La date honnête

    @ViewBuilder
    private var forecastCard: some View {
        Card {
            Text("À TON RYTHME RÉEL").sectionLabel()
            if let f = model.forecast(for: live) {
                Text(forecastLine(f))
                    .font(.app(17, .semibold))
                    .foregroundStyle(f.daysLate.map { $0 > 0 } == true
                                     ? Palette.accent : Color(hex: 0xD6D6D9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: "Tu boucles environ %.1f marche%@ par semaine sur ce projet.",
                            f.perWeek, f.perWeek >= 2 ? "s" : ""))
                    .font(.app(13, .medium))
                    .foregroundStyle(Palette.textTertiary)
            } else {
                Text("Encore trop tôt pour dire quoi que ce soit d'honnête. Il faut au moins deux marches bouclées.")
                    .font(.app(15, .medium))
                    .foregroundStyle(Palette.textTertiary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func forecastLine(_ f: Planner.Forecast) -> String {
        guard let late = f.daysLate else {
            return "À ce rythme, ce sera terminé vers le \(longDate(f.date))."
        }
        if late > 0 {
            return "À ce rythme, ce sera plutôt le \(longDate(f.date)) — soit \(late) jour\(late > 1 ? "s" : "") après la date annoncée."
        }
        return "À ce rythme, tu es dans les temps : vers le \(longDate(f.date))."
    }

    // MARK: - Le silence

    private var silenceCard: some View {
        Card {
            Text("DES NOUVELLES").sectionLabel()
            if let days = live.daysSinceContact() {
                Text(days == 0
                     ? "Tu as donné des nouvelles aujourd'hui."
                     : "Dernières nouvelles il y a \(days) jour\(days > 1 ? "s" : "").")
                    .font(.app(16, .semibold))
                    .foregroundStyle(days >= 10 ? Palette.accent : Color(hex: 0xD6D6D9))
            } else {
                Text("Tu n'as encore rien noté.")
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color(hex: 0xD6D6D9))
            }

            Text("Ce n'est presque jamais le retard qui blesse. C'est le silence.")
                .font(.app(13, .medium))
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.markContacted(live)
            } label: {
                Text("J'ai donné des nouvelles")
                    .font(.app(15, .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Palette.sand, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    // MARK: - Les marches

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LES MARCHES").sectionLabel()
            Text("Tu es venu voir : c'est le seul endroit où tout est là. Au quotidien, l'app ne t'en montre qu'une.")
                .font(.app(13, .medium))
                .foregroundStyle(Palette.textTertiary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            ForEach(model.steps(of: live)) { step in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { model.toggleStep(step) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .strokeBorder(step.isOpen ? Color.white.opacity(0.18) : Palette.accent,
                                              lineWidth: 2)
                                .frame(width: 22, height: 22)
                            if !step.isOpen {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        Text(step.title)
                            .font(.app(16, .medium))
                            .foregroundStyle(step.isOpen ? Color(hex: 0xD6D6D9) : Palette.textTertiary)
                            .strikethrough(!step.isOpen, color: Palette.textGhost)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addStepField: some View {
        HStack(spacing: 10) {
            TextField("", text: $newStep,
                      prompt: Text("Ajouter une marche").foregroundColor(Palette.textFaint))
                .font(.app(15, .medium))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.accent)
                .focused($addingStep)
                .submitLabel(.done)
                .onSubmit(addStep)
            if !newStep.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: addStep) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .frame(height: 52)
        .background(Palette.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Palette.hairline, lineWidth: 1))
    }

    private func addStep() {
        let value = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        newStep = ""
        addingStep = false
        guard !value.isEmpty else { return }
        model.addStep(value, to: live.id)
    }

    private var archiveButton: some View {
        Button {
            model.archive(live)
            dismiss()
        } label: {
            Text("Ranger ce projet")
                .font(.app(14, .medium))
                .foregroundStyle(Palette.textGhost)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }
}

// MARK: - Carte et étiquette

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private extension Text {
    func sectionLabel() -> some View {
        self.font(.app(11, .bold))
            .tracking(2)
            .foregroundStyle(Palette.sandGhost)
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
