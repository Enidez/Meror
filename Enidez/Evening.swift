//
//  Evening.swift
//  Enidez
//
//  Le rythme de la journée : le mot du milieu, le bilan du soir, et les
//  rappels locaux qui les portent.
//
//  Trois rendez-vous au plus, jamais davantage — et celui du milieu ne sonne
//  que s'il a quelque chose d'utile à dire. Le silence est la valeur par défaut.
//

import Foundation
import UserNotifications

/// Une journée refermée : ce qu'on a ressenti, ce qui a compté.
struct DayNote: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var mood: Mood?
    var mattered: String = ""
    var closedCount: Int = 0   // combien des deux choses faites
}

// MARK: - Le mot du milieu de journée

/// Ce qu'on a à dire au milieu de la journée. `nil` quand il n'y a rien :
/// dans ce cas, on ne sonne pas du tout.
enum Nudge: Equatable {
    /// Une échéance tombe demain et n'est pas dans les deux du jour.
    case deadlineTomorrow(String)
    /// Le tri du matin n'a pas eu lieu.
    case nothingPicked
    /// Rien de commencé, la journée avance.
    case notStarted(String)
    /// Une des deux est bouclée, l'autre attend.
    case oneLeft(String)
    /// Les deux sont faites — on le dit, sans en réclamer plus.
    case bothDone

    var title: String {
        switch self {
        case .deadlineTomorrow: "C'est pour demain"
        case .nothingPicked:    "Deux choses, et c'est tout"
        case .notStarted:       "Il reste du jour"
        case .oneLeft:          "Une de faite"
        case .bothDone:         "Tes deux choses sont bouclées"
        }
    }

    var body: String {
        switch self {
        case .deadlineTomorrow(let title):
            "\(title) — c'est demain. On la met dans tes deux ?"
        case .nothingPicked:
            "Tu n'as pas encore choisi. Deux minutes suffisent."
        case .notStarted(let title):
            "\(title) t'attend. Quinze minutes, et c'est déjà quelque chose."
        case .oneLeft(let title):
            "Il te reste \(title). Rien ne presse."
        case .bothDone:
            "Le reste du jour t'appartient."
        }
    }
}

enum Reminders {

    private static let morningID = "meror.reminder.morning"
    private static let middayID  = "meror.reminder.midday"
    private static let eveningID = "meror.reminder.evening"

    /// Demande l'autorisation puis (re)pose les deux rappels fixes.
    /// Celui du milieu est posé à part, parce que son contenu dépend du jour.
    static func enable(eveningHour: Int, eveningMinute: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        schedule(id: morningID, hour: 8, minute: 0, repeats: true,
                 title: "Prêt pour ta journée ?",
                 body: "Un moment pour choisir tes deux choses.")
        schedule(id: eveningID, hour: eveningHour, minute: eveningMinute, repeats: true,
                 title: "On clôt la journée ?",
                 body: "Ce qui est fait, comment tu te sens. Une minute.")
    }

    /// Repose le mot du milieu pour la prochaine échéance utile. Un `nudge`
    /// à `nil` retire simplement celui qui était en attente : on se tait.
    static func scheduleMidday(_ nudge: Nudge?, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [middayID])
        guard let nudge else { return }
        schedule(id: middayID, hour: hour, minute: minute, repeats: false,
                 title: nudge.title, body: nudge.body)
    }

    static func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID, middayID, eveningID])
    }

    private static func schedule(id: String, hour: Int, minute: Int, repeats: Bool,
                                 title: String, body: String) {
        var comps = DateComponents()
        comps.hour = max(0, min(23, hour))
        comps.minute = max(0, min(59, minute))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
