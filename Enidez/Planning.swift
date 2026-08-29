//
//  Planning.swift
//  Enidez
//
//  Le backlog et le tri. Tout ce que la personne a à faire vit dans `items` ;
//  chaque matin le `Planner` en propose deux, avec une raison. Le reste est
//  gardé de côté — vraiment, pas juste en mot.
//

import Foundation

/// Une chose à faire. Peut être estimée, datée, faite, ou choisie pour un jour.
struct Item: Identifiable, Codable {
    var id = UUID()
    var title: String
    var minutes: Int?          // estimation, optionnelle
    var due: Date?             // échéance, optionnelle
    var createdAt = Date()
    var doneAt: Date?          // nil = à faire
    var pickedOn: Date?        // dernier jour où c'était une des deux
    var deferrals = 0          // nombre de fois écartée du jour à la main

    var isOpen: Bool { doneAt == nil }

    /// Choisie pour aujourd'hui et pas encore faite.
    var isPickedToday: Bool {
        guard let pickedOn, isOpen else { return false }
        return Calendar.current.isDateInToday(pickedOn)
    }

    var estimateLabel: String? {
        minutes.map { "\($0) min" }
    }

    /// Quelques choses pour ne pas démarrer sur du vide (premier lancement).
    static var starter: [Item] {
        let now = Date()
        let day: TimeInterval = 86_400
        return [
            Item(title: "Appeler le plombier", minutes: 5,
                 createdAt: now.addingTimeInterval(-3 * day)),
            Item(title: "Rédiger le mail aux impôts", minutes: 15,
                 createdAt: now.addingTimeInterval(-1 * day)),
            Item(title: "Prendre rendez-vous chez le dentiste",
                 createdAt: now.addingTimeInterval(-6 * day)),
            Item(title: "Ranger le bureau", minutes: 20,
                 createdAt: now.addingTimeInterval(-2 * day))
        ]
    }
}

/// Propose les deux choses du jour, et sait dire pourquoi.
enum Planner {

    struct Suggestion: Identifiable {
        var id: UUID { item.id }
        var item: Item
        var reason: String
    }

    /// Les deux meilleures candidates parmi le backlog ouvert non choisi.
    static func suggestions(from items: [Item], on day: Date = Date()) -> [Suggestion] {
        let pool = items.filter { $0.isOpen && !$0.isPickedToday }
        let ranked = pool
            .map { (item: $0, score: score($0, on: day)) }
            .sorted { $0.score > $1.score }
            .prefix(2)
        return ranked.map { Suggestion(item: $0.item, reason: reason(for: $0.item, on: day)) }
    }

    // MARK: - Score

    private static func score(_ item: Item, on day: Date) -> Double {
        var s = 0.0
        let cal = Calendar.current

        // Ancienneté : ce qui traîne remonte, doucement, plafonné.
        let age = cal.dateComponents([.day], from: item.createdAt, to: day).day ?? 0
        s += min(Double(max(age, 0)), 14) * 1.5

        // Échéance proche : gros poids si c'est dans les trois jours.
        if let due = item.due {
            let days = cal.dateComponents([.day], from: day, to: due).day ?? 99
            if days <= 0 { s += 60 }
            else if days <= 3 { s += 40 }
            else if days <= 7 { s += 15 }
        }

        // Reportée à la main : on la fait réémerger, sans harceler.
        s += Double(min(item.deferrals, 4)) * 6

        // Continuité : commencée un autre jour mais pas finie.
        if let picked = item.pickedOn, !cal.isDateInToday(picked) {
            s += 12
        }

        // Petites tâches : un léger coup de pouce (une victoire rapide).
        if let m = item.minutes, m <= 10 { s += 4 }

        return s
    }

    private static func reason(for item: Item, on day: Date) -> String {
        let cal = Calendar.current

        if let due = item.due {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: day),
                                          to: cal.startOfDay(for: due)).day ?? 99
            switch days {
            case ..<0:  return "en retard"
            case 0:     return "c'est aujourd'hui"
            case 1:     return "c'est demain"
            case 2...3: return "dans \(days) jours"
            default:    break
            }
        }
        if item.deferrals >= 2 {
            return "reportée \(item.deferrals) fois"
        }
        if let picked = item.pickedOn, !cal.isDateInToday(picked) {
            return "commencée, pas finie"
        }
        let age = cal.dateComponents([.day], from: cal.startOfDay(for: item.createdAt),
                                     to: cal.startOfDay(for: day)).day ?? 0
        switch age {
        case 0:      return "notée aujourd'hui"
        case 1:      return "notée hier"
        case 2...6:  return "depuis \(age) jours"
        default:     return "de côté depuis un moment"
        }
    }
}
