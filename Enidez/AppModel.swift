//
//  AppModel.swift
//  Enidez
//
//  État de l'application et coordination du parcours.
//  La complexité — tout ce que tu as à faire, et le tri — reste ici, côté
//  machine. Toi, tu ne vois que deux choses à la fois.
//
//  Deux temps :
//   1. le rituel du matin — plein écran, une fois par jour
//      (bienvenue → prénom → réveil → café → le tri) ;
//   2. l'app — trois onglets : Aujourd'hui · À venir · Toi.
//

import SwiftUI

/// Les étapes du rituel du matin, puis `.app` une fois qu'on est entré.
enum Screen: String, Codable {
    case welcome
    case onboarding
    case wakeUp
    case coffeeBreak
    case afterCoffee
    case triage       // Le tri : quelles deux choses aujourd'hui
    case app          // Rituel terminé : on vit dans les onglets
}

/// Les onglets de l'app.
enum AppTab: String, Codable, CaseIterable {
    case today
    case upcoming
    case you
}

/// Une échéance à venir (le calendrier). Sera fondu dans `Item` plus tard.
struct Deadline: Identifiable, Codable {
    var id = UUID()
    var day: String       // « MER 19 »
    var title: String
    var hasAccent: Bool = false
}

@MainActor
@Observable
final class AppModel {
    /// Le prénom de la personne accompagnée.
    var name = "Léa" { didSet { persist() } }

    /// Vrai une fois le prénom donné.
    var isOnboarded = false { didSet { persist() } }

    /// Où l'on en est : une étape du rituel, ou `.app`.
    var screen: Screen = .welcome { didSet { persist() } }

    /// L'onglet actif quand `screen == .app`.
    var tab: AppTab = .today { didSet { persist() } }

    /// Vrai quand le minuteur de focus est ouvert par-dessus Aujourd'hui.
    var inFocus = false

    /// Vrai quand l'assistant écoute (retour visuel du micro).
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

    /// Les pensées parasites confiées pendant un focus.
    var capturedThoughts: [String] = [] { didSet { persist() } }

    /// Tout ce que tu as à faire. Le backlog. La plupart est gardée de côté ;
    /// deux choses au plus sont « choisies » pour le jour.
    var items: [Item] = Item.starter { didSet { persist() } }

    /// Les échéances datées (onglet À venir).
    var deadlines: [Deadline] = [
        Deadline(day: "MER 19", title: "Dossier mutuelle", hasAccent: true),
        Deadline(day: "VEN 21", title: "Rendez-vous kiné"),
        Deadline(day: "LUN 24", title: "Courses de la semaine")
    ] { didSet { persist() } }

    /// Sélection en cours sur l'écran de tri (max 2).
    var triagePicks: [UUID] = []

    /// Accès à Apple Santé et au micro.
    private let health = HealthService()
    let speech = SpeechService()

    private var isReady = false

    // MARK: - Les deux choses du jour

    /// Les choses choisies pour aujourd'hui, encore ouvertes, dans l'ordre.
    var todayPicks: [Item] {
        items.filter(\.isPickedToday)
    }

    /// La chose du moment.
    var currentPick: Item? { todayPicks.first }

    /// La chose suivante, discrète.
    var nextPick: Item? { todayPicks.dropFirst().first }

    /// Ce qui est gardé de côté : ouvert, non choisi aujourd'hui, sans échéance passée.
    var heldItems: [Item] {
        items.filter { $0.isOpen && !$0.isPickedToday }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    /// Nombre de choses bouclées cette semaine (vrai compteur).
    var closedThisWeek: Int {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return items.filter { ($0.doneAt ?? .distantPast) >= weekStart }.count
    }

    // MARK: - Cycle de vie

    init() {
        restore()
        isReady = true
        persist()
    }

    private func restore() {
        guard let saved = Store.load() else { return }

        name = saved.name
        isOnboarded = saved.isOnboarded
        tab = saved.tab
        items = saved.items
        deadlines = saved.deadlines
        capturedThoughts = saved.capturedThoughts
        life.lastMood = saved.lastMood
        life.targetBedtime = saved.targetBedtime

        if Calendar.current.isDateInToday(saved.savedAt) {
            screen = saved.screen
        } else {
            screen = isOnboarded ? .wakeUp : .welcome
            tab = .today
        }

        // Relancé en plein tri : on repropose deux choses (la sélection en
        // cours n'est pas sauvegardée, c'est un choix du moment).
        if screen == .triage {
            triagePicks = Planner.suggestions(from: items).map(\.item.id)
        }
    }

    private func persist() {
        guard isReady else { return }
        Store.save(StoredState(
            name: name,
            isOnboarded: isOnboarded,
            screen: screen,
            tab: tab,
            items: items,
            deadlines: deadlines,
            capturedThoughts: capturedThoughts,
            lastMood: life.lastMood,
            targetBedtime: life.targetBedtime,
            savedAt: Date()
        ))
    }

    // MARK: - Onboarding

    func completeOnboarding(name raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { name = trimmed }
        isOnboarded = true
        go(to: .wakeUp)
    }

    // MARK: - Navigation

    func go(to screen: Screen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            self.screen = screen
        }
    }

    func show(_ tab: AppTab) {
        withAnimation(.easeInOut(duration: 0.25)) { self.tab = tab }
    }

    /// Sort du rituel et entre dans l'app.
    func enterApp() {
        withAnimation(.easeInOut(duration: 0.4)) {
            screen = .app
            tab = .today
        }
    }

    // MARK: - Tri du matin

    /// Ouvre l'écran de tri, pré-rempli des deux suggestions.
    func startTriage() {
        triagePicks = Planner.suggestions(from: items).map(\.item.id)
        go(to: .triage)
    }

    /// La raison affichée sous une suggestion, s'il y en a une.
    func triageReason(for id: UUID) -> String? {
        Planner.suggestions(from: items).first { $0.item.id == id }?.reason
    }

    /// Coche / décoche une chose pour aujourd'hui (deux au maximum).
    func toggleTriage(_ id: UUID) {
        if let index = triagePicks.firstIndex(of: id) {
            triagePicks.remove(at: index)
        } else if triagePicks.count < 2 {
            triagePicks.append(id)
        }
    }

    /// Fige la sélection du jour et entre dans l'app.
    func confirmTriage() {
        let suggested = Set(Planner.suggestions(from: items).map(\.item.id))
        let now = Date()
        for index in items.indices where items[index].isOpen {
            let id = items[index].id
            if triagePicks.contains(id) {
                items[index].pickedOn = now
            } else if suggested.contains(id) {
                // Suggérée mais écartée à la main : on s'en souvient.
                items[index].deferrals += 1
            }
        }
        enterApp()
    }

    // MARK: - Faire / défaire

    /// Marque la chose du moment comme faite et ferme le focus.
    func completeCurrentPick() {
        if let index = items.firstIndex(where: { $0.isPickedToday }) {
            items[index].doneAt = Date()
        }
        inFocus = false
        tab = .today
    }

    // MARK: - Contexte de vie

    func loadHealthData() async {
        guard let snapshot = await health.requestAndFetch() else { return }
        life.healthConnected = snapshot.connected
        if let value = snapshot.lastNightSleepHours { life.lastNightSleepHours = value }
        if let value = snapshot.averageSleepHours { life.averageSleepHours = value }
        if let value = snapshot.averageBedtime { life.averageBedtime = value }
        if let value = snapshot.stepsToday { life.stepsToday = value }
        if let value = snapshot.activeEnergyToday { life.activeEnergyToday = value }
    }

    func record(mood: Mood) {
        life.lastMood = mood
    }

    // MARK: - Saisie (écrite ou dictée)

    /// Porte d'entrée commune au clavier et à la voix.
    func capture(_ text: String) {
        interpret(text)
    }

    private func interpret(_ phrase: String) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        if inFocus {
            capturedThoughts.append(phrase)
            return
        }

        if screen == .app && tab == .upcoming {
            deadlines.append(VoiceInterpreter.deadline(from: phrase))
            return
        }

        var item = VoiceInterpreter.item(from: phrase)

        if screen == .triage {
            items.append(item)
            if triagePicks.count < 2 { triagePicks.append(item.id) }
            return
        }

        // Dans l'app : s'il reste de la place dans les deux, ça en devient une.
        if screen == .app && tab == .today && todayPicks.count < 2 {
            item.pickedOn = Date()
        }
        items.append(item)
    }
}
