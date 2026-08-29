//
//  AppModel.swift
//  Enidez
//
//  État de l'application et coordination du parcours.
//  La complexité (priorisation, planification) reste ici, côté machine ;
//  l'utilisateur ne voit jamais la mécanique.
//

import SwiftUI

/// Les écrans du parcours, dans l'ordre narratif du matin.
/// `String` + `Codable` pour pouvoir retrouver son fil au relancement.
enum Screen: String, Codable {
    case welcome      // 3i — Bienvenue
    case wakeUp       // 3a — Le réveil
    case coffeeBreak  // 3b — La pause café
    case afterCoffee  // 3c — Après le café
    case twoThings    // 3d — Les deux choses
    case today        // 3e — Aujourd'hui
    case hyperfocus   // 3g — Hyperfocus
    case upcoming     // 3f — Les jours à venir
    case evolution    // 3h — Ton évolution
    case profile      // Profil : ce que l'assistant sait de toi
}

/// Une chose qui compte dans la journée.
struct DayTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var minutes: Int
    var isDone = false
}

/// Une échéance à venir.
struct Deadline: Identifiable {
    let id = UUID()
    var day: String       // « MER 19 »
    var title: String
    var hasAccent: Bool = false
}

@MainActor
@Observable
final class AppModel {
    /// Le prénom de la personne accompagnée.
    let name = "Léa"

    /// L'écran affiché. Une seule chose à l'écran à la fois.
    var screen: Screen = .welcome { didSet { persist() } }

    /// Vrai quand l'assistant écoute (retour visuel du micro).
    /// Transitoire : jamais sauvegardé.
    var isListening = false

    /// Ce que l'assistant sait de toi : sommeil, activité, focus, humeur.
    /// Part de données d'exemple, puis s'enrichit avec Apple Santé.
    var life = LifeContext.sample { didSet { persist() } }

    /// Accès à Apple Santé.
    private let health = HealthService()

    /// Les deux choses qui comptent maintenant.
    /// La première est active, la seconde attend son tour.
    var tasks: [DayTask] = [
        DayTask(title: "Appeler le plombier", minutes: 5),
        DayTask(title: "Rédiger le mail aux impôts", minutes: 15)
    ] { didSet { persist() } }

    /// La tâche du moment (la première non terminée).
    var currentTask: DayTask? {
        tasks.first { !$0.isDone }
    }

    /// La tâche suivante, discrète, sous la carte du moment.
    var nextTask: DayTask? {
        tasks.filter { !$0.isDone }.dropFirst().first
    }

    /// Les prochaines échéances des jours à venir.
    let deadlines: [Deadline] = [
        Deadline(day: "MER 19", title: "Dossier mutuelle", hasAccent: true),
        Deadline(day: "VEN 21", title: "Rendez-vous kiné"),
        Deadline(day: "LUN 24", title: "Courses de la semaine")
    ]

    /// Faux tant que le chargement initial n'est pas fini : empêche de
    /// réécrire l'état pendant qu'on est en train de le lire.
    private var isReady = false

    // MARK: - Cycle de vie

    init() {
        restore()
        isReady = true
        // Aligne tout de suite le disque sur l'état réellement affiché
        // (utile quand `restore` a remis les compteurs à zéro pour un nouveau jour).
        persist()
    }

    /// Relit l'état sauvegardé. « Un jour » : le même jour on retrouve son fil ;
    /// un jour plus tard, on repart du début et les deux choses reprennent à zéro.
    private func restore() {
        guard let saved = Store.load() else { return }

        tasks = saved.tasks
        life.lastMood = saved.lastMood
        life.targetBedtime = saved.targetBedtime

        if Calendar.current.isDateInToday(saved.savedAt) {
            screen = saved.screen
        } else {
            screen = .welcome
            for index in tasks.indices { tasks[index].isDone = false }
        }
    }

    /// Écrit l'état courant. Sans effet pendant le chargement initial.
    private func persist() {
        guard isReady else { return }
        Store.save(StoredState(
            screen: screen,
            tasks: tasks,
            lastMood: life.lastMood,
            targetBedtime: life.targetBedtime,
            savedAt: Date()
        ))
    }

    // MARK: - Navigation

    /// Passe à l'écran donné, en douceur.
    func go(to screen: Screen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            self.screen = screen
        }
    }

    /// Marque la tâche du moment comme faite et enchaîne.
    func completeCurrentTask() {
        if let index = tasks.firstIndex(where: { !$0.isDone }) {
            tasks[index].isDone = true
        }
        // S'il reste une chose, on repart sur « Aujourd'hui » ;
        // sinon la journée est libre.
        go(to: .today)
    }

    // MARK: - Contexte de vie

    /// Charge les données d'Apple Santé et les fusionne dans le contexte.
    /// En cas d'échec (indisponible, refusé), on garde les données d'exemple.
    func loadHealthData() async {
        guard let snapshot = await health.requestAndFetch() else { return }
        life.healthConnected = snapshot.connected
        if let value = snapshot.lastNightSleepHours { life.lastNightSleepHours = value }
        if let value = snapshot.averageSleepHours { life.averageSleepHours = value }
        if let value = snapshot.averageBedtime { life.averageBedtime = value }
        if let value = snapshot.stepsToday { life.stepsToday = value }
        if let value = snapshot.activeEnergyToday { life.activeEnergyToday = value }
    }

    /// Enregistre l'humeur ressentie du moment.
    func record(mood: Mood) {
        life.lastMood = mood
    }
}
