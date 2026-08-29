//
//  AppModel.swift
//  Enidez
//
//  État de l'application et coordination du parcours.
//  La complexité (priorisation, planification) reste ici, côté machine ;
//  l'utilisateur ne voit jamais la mécanique.
//
//  Deux temps :
//   1. le rituel du matin — un plein écran linéaire, fait une fois par jour
//      (bienvenue → prénom → réveil → café → les deux choses) ;
//   2. l'app — trois onglets : Aujourd'hui · À venir · Toi.
//

import SwiftUI

/// Les étapes du rituel du matin, puis `.app` une fois qu'on est entré.
enum Screen: String, Codable {
    case welcome      // Bienvenue
    case onboarding   // Premier lancement : ton prénom
    case wakeUp       // Le réveil
    case coffeeBreak  // La pause café
    case afterCoffee  // Après le café
    case twoThings    // Les deux choses
    case app          // Rituel terminé : on vit dans les onglets
}

/// Les onglets de l'app.
enum AppTab: String, Codable, CaseIterable {
    case today     // Aujourd'hui
    case upcoming  // À venir
    case you       // Toi
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

    /// Où l'on en est : une étape du rituel, ou `.app`.
    var screen: Screen = .welcome { didSet { persist() } }

    /// L'onglet actif quand `screen == .app`.
    var tab: AppTab = .today { didSet { persist() } }

    /// Vrai quand le minuteur de focus est ouvert par-dessus l'onglet
    /// Aujourd'hui. Transitoire : le focus ne survit pas à une fermeture.
    var inFocus = false

    /// Vrai quand l'assistant écoute (retour visuel du micro).
    /// Transitoire. Ouvre et ferme le micro, puis interprète ce qui a été dit.
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
    var life = LifeContext.sample { didSet { persist() } }

    /// Les pensées parasites confiées pendant un focus. On les garde, on ne
    /// les affiche pas en pleine figure.
    var capturedThoughts: [String] = [] { didSet { persist() } }

    /// Accès à Apple Santé et au micro.
    private let health = HealthService()
    let speech = SpeechService()

    /// Les deux choses qui comptent maintenant.
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

    /// Faux tant que le chargement initial n'est pas fini.
    private var isReady = false

    // MARK: - Cycle de vie

    init() {
        restore()
        isReady = true
        persist()
    }

    /// Relit l'état sauvegardé. « Un jour » : le même jour on retrouve son fil ;
    /// un jour plus tard on refait le réveil, et les deux choses reprennent à zéro.
    private func restore() {
        guard let saved = Store.load() else { return }

        name = saved.name
        isOnboarded = saved.isOnboarded
        tab = saved.tab
        tasks = saved.tasks
        deadlines = saved.deadlines
        capturedThoughts = saved.capturedThoughts
        life.lastMood = saved.lastMood
        life.targetBedtime = saved.targetBedtime

        if Calendar.current.isDateInToday(saved.savedAt) {
            screen = saved.screen
        } else {
            screen = isOnboarded ? .wakeUp : .welcome
            tab = .today
            for index in tasks.indices { tasks[index].isDone = false }
        }
    }

    private func persist() {
        guard isReady else { return }
        Store.save(StoredState(
            name: name,
            isOnboarded: isOnboarded,
            screen: screen,
            tab: tab,
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
    func completeOnboarding(name raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { name = trimmed }
        isOnboarded = true
        go(to: .wakeUp)
    }

    // MARK: - Navigation

    /// Passe à une étape du rituel, en douceur.
    func go(to screen: Screen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            self.screen = screen
        }
    }

    /// Sort du rituel et entre dans l'app, sur l'onglet Aujourd'hui.
    func enterApp() {
        withAnimation(.easeInOut(duration: 0.4)) {
            screen = .app
            tab = .today
        }
    }

    /// Change d'onglet.
    func show(_ tab: AppTab) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.tab = tab
        }
    }

    /// Marque la tâche du moment comme faite et ferme le focus.
    func completeCurrentTask() {
        if let index = tasks.firstIndex(where: { !$0.isDone }) {
            tasks[index].isDone = true
        }
        inFocus = false
        tab = .today
    }

    // MARK: - Contexte de vie

    /// Charge les données d'Apple Santé et les fusionne dans le contexte.
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

    // MARK: - Saisie (écrite ou dictée)

    /// Porte d'entrée commune au clavier et à la voix : la phrase est
    /// interprétée selon le contexte, exactement comme la dictée.
    func capture(_ text: String) {
        interpret(text)
    }

    /// Donne un sens à ce qui vient d'être dit ou écrit, selon le contexte.
    private func interpret(_ phrase: String) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        if inFocus {
            // « Une pensée parasite ? Dis-la-moi, je la garde. »
            capturedThoughts.append(phrase)
            return
        }

        if screen == .app && tab == .upcoming {
            // « Jeudi, penser au dentiste » — on la place.
            deadlines.append(VoiceInterpreter.deadline(from: phrase))
            return
        }

        let newThing = VoiceInterpreter.task(from: phrase)

        if screen == .twoThings {
            // « Changer une des deux » : on remplace celle qui attend.
            if let waiting = tasks.firstIndex(where: { !$0.isDone && $0.id != currentTask?.id }) {
                tasks[waiting] = newThing
            } else {
                tasks.append(newThing)
            }
            return
        }

        // Partout ailleurs : ce qui est dit devient la chose du moment.
        if let current = tasks.firstIndex(where: { !$0.isDone }) {
            tasks.insert(newThing, at: current)
        } else {
            tasks.append(newThing)
        }
    }
}
