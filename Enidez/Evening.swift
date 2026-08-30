//
//  Evening.swift
//  Enidez
//
//  Le bilan du soir : le pendant du rituel du matin. Ce qui est fait ou non,
//  comment on se sent, une chose qui a compté. Ce qui n'est pas fini repart
//  dans le tri de demain.
//
//  Et les deux rappels quotidiens : le matin pour ouvrir la journée, le soir
//  pour la clore. Locaux, discrets — jamais plus de deux.
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

enum Reminders {

    private static let morningID = "meror.reminder.morning"
    private static let eveningID = "meror.reminder.evening"

    /// Demande l'autorisation puis (re)pose les deux rappels. `evening` est
    /// l'heure du bilan (calée sur l'objectif de coucher moins ~1 h 30).
    static func enable(eveningHour: Int, eveningMinute: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        schedule(id: morningID, hour: 8, minute: 0,
                 title: "Prêt pour ta journée ?",
                 body: "Un moment pour choisir tes deux choses.")
        schedule(id: eveningID, hour: eveningHour, minute: eveningMinute,
                 title: "On clôt la journée ?",
                 body: "Ce qui est fait, comment tu te sens. Une minute.")
    }

    static func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
    }

    private static func schedule(id: String, hour: Int, minute: Int, title: String, body: String) {
        var comps = DateComponents()
        comps.hour = max(0, min(23, hour))
        comps.minute = max(0, min(59, minute))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
