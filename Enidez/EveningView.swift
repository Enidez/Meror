//
//  EveningView.swift
//  Enidez
//
//  Le bilan du soir : le pendant du rituel du matin. Trois pas, courts.
//  Ce qui n'est pas fini repart dans le tri de demain, tout seul.
//

import SwiftUI

struct EveningView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var mood: Mood?
    @State private var mattered = ""
    @FocusState private var writing: Bool

    var body: some View {
        PhoneScreen(time: "21:30", trailing: "ce soir") {
            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer()

                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))

                Spacer()

                footer
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 24)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 14) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 32, height: 32)
                        .background(Palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Palette.accent : Color.white.opacity(0.12))
                        .frame(width: i == step ? 24 : 7, height: 4)
                }
            }
            Spacer()
            if step == 0 {
                Button("Plus tard") { model.snoozeEvening() }
                    .font(.app(14, .semibold))
                    .foregroundStyle(Palette.textMuted)
                    .buttonStyle(.plain)
            }
        }
        .padding(.top, 30)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 22) {
                dot
                (Text("Bonsoir \(model.name).\n")
                    + Text("Tu as fait quoi ?").foregroundColor(Palette.textSecondary))
                    .bigTitle(32)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(model.pickedToday) { item in
                        doneRow(item)
                    }
                }
                .padding(.top, 4)
            }
        case 1:
            VStack(alignment: .leading, spacing: 22) {
                dot
                (Text("Ce soir, tu es\n")
                    + Text("plutôt…").foregroundColor(Palette.textSecondary))
                    .bigTitle(32)
                    .foregroundStyle(Palette.textPrimary)

                VStack(spacing: 10) {
                    ForEach(Mood.allCases) { m in
                        choice(m.rawValue, selected: mood == m) {
                            mood = m
                            withAnimation(.easeInOut(duration: 0.25)) { step = 2 }
                        }
                    }
                }
                .padding(.top, 4)
            }
        default:
            VStack(alignment: .leading, spacing: 22) {
                dot
                (Text("Une chose qui a\n")
                    + Text("compté aujourd'hui.").foregroundColor(Palette.textSecondary))
                    .bigTitle(32)
                    .foregroundStyle(Palette.textPrimary)

                TextField("", text: $mattered,
                          prompt: Text("Même toute petite.").foregroundColor(Palette.textFaint),
                          axis: .vertical)
                    .lineLimit(1...4)
                    .font(.app(20, .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .tint(Palette.accent)
                    .focused($writing)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(writing ? Palette.accent : Palette.hairline)
                            .frame(height: 2)
                    }
                    .padding(.top, 4)
            }
        }
    }

    private var dot: some View {
        Circle().fill(Palette.accent).frame(width: 8, height: 8)
    }

    private func doneRow(_ item: Item) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { model.toggleDone(item.id) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(item.isOpen ? Color.white.opacity(0.18) : Palette.accent, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if !item.isOpen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                Text(item.title)
                    .font(.app(17, .bold))
                    .foregroundStyle(item.isOpen ? Palette.textSecondary : Palette.textPrimary)
                    .strikethrough(!item.isOpen, color: Palette.textMuted)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.app(16, .semibold))
                    .foregroundStyle(selected ? .black : Palette.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(selected ? Palette.accent : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pied

    @ViewBuilder
    private var footer: some View {
        switch step {
        case 0:
            PrimaryButton(title: "Continuer") {
                withAnimation(.easeInOut(duration: 0.25)) { step = 1 }
            }
        case 2:
            VStack(spacing: 10) {
                PrimaryButton(title: "Bonne nuit") { finish() }
                Button("Passer") { finish() }
                    .font(.app(15, .semibold))
                    .foregroundStyle(Palette.textFaint)
                    .buttonStyle(.plain)
            }
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func finish() {
        writing = false
        model.completeEvening(mood: mood, mattered: mattered)
    }
}
