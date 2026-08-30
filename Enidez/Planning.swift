//
//  Planning.swift
//  Enidez
//
//  Le backlog et le tri. Tout ce que la personne a à faire vit dans `items` ;
//  chaque matin le `Planner` en propose deux, avec une raison. Le reste est
//  gardé de côté — vraiment, pas juste en mot.
//

import Foundation

// MARK: - Ce que la personne nous dit d'elle au premier lancement

/// Le moment où elle tient le mieux.
enum EnergyMoment: String, Codable, CaseIterable, Identifiable {
    case morning = "Le matin"
    case afternoon = "L'après-midi"
    case evening = "Le soir"
    case itVaries = "Ça change tout le temps"

    var id: String { rawValue }

    var period: FocusPeriod? {
        switch self {
        case .morning:   .morning
        case .afternoon: .afternoon
        case .evening:   .evening
        case .itVaries:  nil
        }
    }
}

/// Ce qui lui complique le plus les journées.
enum DailyStruggle: String, Codable, CaseIterable, Identifiable {
    case scattered = "Je me disperse, je perds le fil"
    case postpone  = "Je repousse, et après ça m'angoisse"
    case overload  = "J'en demande trop, je m'épuise"
    case starting  = "Le plus dur, c'est de commencer"

    var id: String { rawValue }
}

/// Ce qui, pour elle, fait qu'une journée est bonne.
enum GoodDay: String, Codable, CaseIterable, Identifiable {
    case progress = "Avoir avancé sur l'essentiel"
    case present  = "M'être senti·e posé·e, pas dispersé·e"
    case selfCare = "Avoir pris soin de moi"
    case kept     = "Avoir tenu ce que j'avais prévu"

    var id: String { rawValue }
}

/// Un projet : une chose trop grosse pour tenir dans une journée. On ne la
/// regarde jamais en entier — l'app n'en sort qu'une marche à la fois.
///
/// C'est la réponse au blocage devant le bloc : ce n'est pas la volonté qui
/// manque, c'est que rien n'est assez petit pour être commencé.
struct Project: Identifiable, Codable {
    var id = UUID()
    var title: String
    /// Pour qui, ou pourquoi. Ce qu'on se rappelle quand on n'a plus envie.
    var why: String = ""
    var due: Date?
    var createdAt = Date()
    var archivedAt: Date?

    var isActive: Bool { archivedAt == nil }
}

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
    /// Le projet dont cette chose est une marche, s'il y en a un.
    var projectID: UUID?
    /// Rang de la marche dans son projet : on les propose dans l'ordre.
    var step: Int = 0

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
                 createdAt: now.addingTimeInterval(-2 * day)),
            Item(title: "Dossier mutuelle",
                 due: now.addingTimeInterval(2 * day),
                 createdAt: now.addingTimeInterval(-4 * day)),
            Item(title: "Rendez-vous kiné",
                 due: now.addingTimeInterval(5 * day),
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
    /// `struggle` incline légèrement le tri vers ce qui aide cette personne.
    ///
    /// D'un projet, on ne propose **que sa marche suivante** : les autres sont
    /// écartées d'office. C'est ce qui empêche de se retrouver devant le bloc.
    static func suggestions(from items: [Item],
                            projects: [Project] = [],
                            struggle: DailyStruggle? = nil,
                            on day: Date = Date()) -> [Suggestion] {
        let byID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let pool = items
            .filter { $0.isOpen && !$0.isPickedToday }
            .filter { item in
                guard let pid = item.projectID else { return true }
                guard byID[pid]?.isActive == true else { return false }
                return Planner.nextStep(of: pid, in: items)?.id == item.id
            }
        let ranked = pool
            .map { (item: $0, score: score($0, project: $0.projectID.flatMap { byID[$0] },
                                           struggle: struggle, on: day)) }
            .sorted { $0.score > $1.score }
            .prefix(2)
        return ranked.map {
            Suggestion(item: $0.item,
                       reason: reason(for: $0.item,
                                      project: $0.item.projectID.flatMap { byID[$0] },
                                      on: day))
        }
    }

    /// La première marche encore ouverte d'un projet, dans l'ordre.
    static func nextStep(of projectID: UUID, in items: [Item]) -> Item? {
        items.filter { $0.projectID == projectID && $0.isOpen }
            .min { $0.step < $1.step }
    }

    /// Où en est un projet : marches faites sur marches totales.
    static func progress(of projectID: UUID, in items: [Item]) -> (done: Int, total: Int) {
        let steps = items.filter { $0.projectID == projectID }
        return (steps.filter { !$0.isOpen }.count, steps.count)
    }

    // MARK: - Score

    private static func score(_ item: Item, project: Project?,
                              struggle: DailyStruggle?, on day: Date) -> Double {
        var s = 0.0
        let cal = Calendar.current

        // Ancienneté : ce qui traîne remonte, doucement, plafonné.
        let age = cal.dateComponents([.day], from: item.createdAt, to: day).day ?? 0
        s += min(Double(max(age, 0)), 14) * 1.5

        // Une marche de projet compte double : c'est ce qui n'avance jamais
        // tout seul, et c'est là que se joue la promesse tenue.
        if project != nil { s += 18 }

        // L'échéance du projet pèse comme celle de la marche.
        if let pdue = project?.due {
            let days = cal.dateComponents([.day], from: day, to: pdue).day ?? 99
            if days <= 2 { s += 55 }
            else if days <= 7 { s += 30 }
            else if days <= 14 { s += 14 }
        }

        // Échéance proche : gros poids si c'est dans les trois jours.
        if let due = item.due {
            let days = cal.dateComponents([.day], from: day, to: due).day ?? 99
            if days <= 0 { s += 60 }
            else if days <= 3 { s += 40 }
            else if days <= 7 { s += 15 }
        }

        // Reportée à la main : on la fait réémerger, sans harceler.
        let deferWeight = (struggle == .postpone) ? 12.0 : 6.0
        s += Double(min(item.deferrals, 4)) * deferWeight

        // Continuité : commencée un autre jour mais pas finie.
        if let picked = item.pickedOn, !cal.isDateInToday(picked) {
            s += 12
        }

        // Petites tâches : une victoire rapide. Plus fort si démarrer est dur.
        if let m = item.minutes, m <= 10 {
            s += (struggle == .starting) ? 14 : 4
        }

        return s
    }

    private static func reason(for item: Item, project: Project?, on day: Date) -> String {
        let cal = Calendar.current

        // Nommer le projet : la marche cesse d'être une corvée isolée, elle
        // redevient un pas vers quelque chose qu'on a promis.
        if let project {
            if let pdue = project.due {
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: day),
                                              to: cal.startOfDay(for: pdue)).day ?? 99
                switch days {
                case ..<0:   return "\(project.title) — en retard"
                case 0...2:  return "\(project.title) — plus que \(days == 0 ? "aujourd'hui" : "\(days) j")"
                case 3...14: return "\(project.title) — dans \(days) jours"
                default:     break
                }
            }
            return "prochaine marche · \(project.title)"
        }

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
