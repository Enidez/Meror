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
    case onboarding   // Premier lancement : ton prénom
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
struct Deadline: Identifiable, Codable {
    var id = UUID()
    var day: String       // « MER 19 »
    var title: String
    var hasAccent: Bool = false
}

@MainActor
@Observable
final class AppModel {
    /// Le prénom de la personne accompagnée. « Léa » par défaut (aperçus,
    /// données d'exemple) ; remplacé au premier lancement.
    var name = "Léa" { didSet { persist() } }

    /// Vrai une fois le prénom donné : on ne repasse plus par la bienvenue.
    var isOnboarded = false { didSet { persist() } }

    /// L'écran affiché. Une seule chose à l'écran à la fois.
    var screen: Screen = .welcome { didSet { persist() } }

    /// Vrai quand l'assistant écoute (retour visuel du micro).
    /// Transitoire : jamais sauvegardé. Ouvre et ferme le micro, puis
    /// interprète ce qui a été dit selon l'écran où l'on se trouve.
    var isListening = false {
        didSet {
            guard isListening != oldValue else { return }
            if isListening {
                Task { await speech.start() }
            } else {
                interpret(speech.stop())
            }
        }
    }

    /// Ce que l'assistant sait de toi : sommeil, activité, focus, humeur.
    /// Part de données d'exemple, puis s'enrichit avec Apple Santé.
    var life = LifeContext.sample { didSet { persist() } }

    /// Les pensées parasites confiées pendant un focus. On les garde, on ne
    /// les affiche pas en pleine figure.
    var capturedThoughts: [String] = [] { didSet { persist() } }

    /// Accès à Apple Santé et au micro.
    private let health = HealthService()
    let speech = SpeechService()

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
    var deadlines: [Deadline] = [
        Deadline(day: "MER 19", title: "Dossier mutuelle", hasAccent: true),
        Deadline(day: "VEN 21", title: "Rendez-vous kiné"),
        Deadline(day: "LUN 24", title: "Courses de la semaine")
    ] { didSet { persist() } }

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

        name = saved.name
        isOnboarded = saved.isOnboarded
        tasks = saved.tasks
        deadlines = saved.deadlines
        capturedThoughts = saved.capturedThoughts
        life.lastMood = saved.lastMood
        life.targetBedtime = saved.targetBedtime

        if Calendar.current.isDateInToday(saved.savedAt) {
            screen = saved.screen
        } else {
            // Nouveau jour : on repart au début, mais on ne redemande pas le prénom.
            screen = isOnboarded ? .wakeUp : .welcome
            for index in tasks.indices { tasks[index].isDone = false }
        }
    }

    /// Écrit l'état courant. Sans effet pendant le chargement initial.
    private func persist() {
        guard isReady else { return }
        Store.save(StoredState(
            name: name,
            isOnboarded: isOnboarded,
            screen: screen,
            tasks: tasks,
            deadlines: deadlines,
            capturedThoughts: capturedThoughts,
            lastMood: life.lastMood,
            targetBedtime: life.targetBedtime,
            savedAt: Date()
        ))
    }

    // MARK: - Onboarding

    /// Enregistre le prénom donné au premier lancement et enchaîne sur le réveil.
    /// Un prénom vide garde « Léa ».
    func completeOnboarding(name raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { name = trimmed }
        isOnboarded = true
        go(to: .wakeUp)
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

    // MARK: - Voix

    /// Donne un sens à ce qui vient d'être dit, selon l'écran où l'on est.
    /// Une phrase vide ne fait rien.
    private func interpret(_ phrase: String) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        switch screen {
        case .hyperfocus:
            // « Une pensée parasite ? Dis-la-moi, je la garde. »
            capturedThoughts.append(phrase)

        case .upcoming:
            // « Jeudi, penser au dentiste » — on la place.
            deadlines.append(VoiceInterpreter.deadline(from: phrase))

        case .twoThings:
            // « Changer une des deux » : on remplace celle qui attend.
            let newThing = VoiceInterpreter.task(from: phrase)
            if let waiting = tasks.firstIndex(where: { !$0.isDone && $0.id != currentTask?.id }) {
                tasks[waiting] = newThing
            } else {
                tasks.append(newThing)
            }

        default:
            // Partout ailleurs : ce qui est dit devient la chose du moment.
            let newThing = VoiceInterpreter.task(from: phrase)
            if let current = tasks.firstIndex(where: { !$0.isDone }) {
                tasks.insert(newThing, at: current)
            } else {
                tasks.append(newThing)
            }
        }
    }
}
