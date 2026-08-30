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
    case onboarding   // Ton prénom
    case attune       // Trois questions pour te cerner
    case wakeUp
    case coffeeBreak
    case afterCoffee
    case triage       // Le tri : quelles deux choses aujourd'hui
    case app          // Rituel terminé : on vit dans les onglets
    case evening      // Le bilan du soir
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

    static var starter: [Deadline] {
        [
            Deadline(day: "MER 19", title: "Dossier mutuelle", hasAccent: true),
            Deadline(day: "VEN 21", title: "Rendez-vous kiné"),
            Deadline(day: "LUN 24", title: "Courses de la semaine")
        ]
    }
}

@MainActor
@Observable
final class AppModel {
    /// Le prénom de la personne accompagnée.
    var name = "Léa" { didSet { persist() } }

    /// Vrai une fois le prénom donné.
    var isOnboarded = false { didSet { persist() } }

    /// Ce que la personne nous a dit d'elle au premier lancement.
    var energyMoment: EnergyMoment? { didSet { persist() } }
    var dailyStruggle: DailyStruggle? { didSet { persist() } }
    var goodDay: GoodDay? { didSet { persist() } }

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

    /// Les journées refermées (bilan du soir).
    var dayNotes: [DayNote] = [] { didSet { persist() } }

    /// Dernier bilan du soir effectué.
    var eveningDoneOn: Date? { didSet { persist() } }

    /// Rappels matin + soir.
    var remindersOn = false {
        didSet {
            guard isReady, remindersOn != oldValue else { return }
            if remindersOn {
                let (h, m) = eveningReminderTime
                Task {
                    await Reminders.enable(eveningHour: h, eveningMinute: m)
                    refreshMiddayNudge()
                }
            } else {
                Reminders.disable()
            }
            persist()
        }
    }

    /// Tout ce que tu as à faire. Le backlog. La plupart est gardée de côté ;
    /// deux choses au plus sont « choisies » pour le jour.
    var items: [Item] = Item.starter { didSet { persist() } }

    /// Les échéances datées (onglet À venir).
    var deadlines: [Deadline] = Deadline.starter { didSet { persist() } }

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

    /// Ce qui est gardé de côté : ouvert, non choisi aujourd'hui.
    var heldItems: [Item] {
        items.filter { $0.isOpen && !$0.isPickedToday }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    /// Tout ce qui a été choisi aujourd'hui, fait ou non (pour le bilan du soir).
    var pickedToday: [Item] {
        items.filter {
            guard let p = $0.pickedOn else { return false }
            return Calendar.current.isDateInToday(p)
        }
    }

    /// L'heure du rappel du soir : l'objectif de coucher moins ~1 h 30.
    var eveningReminderTime: (hour: Int, minute: Int) {
        let t = Calendar.current.date(byAdding: .minute, value: -90, to: life.targetBedtime)
            ?? life.targetBedtime
        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
        return (c.hour ?? 21, c.minute ?? 30)
    }

    /// L'heure du mot du milieu, calée sur le moment où la personne dit tenir
    /// le mieux : juste après sa fenêtre si c'est le matin, juste avant sinon.
    var middayReminderHour: Int {
        switch energyMoment {
        case .morning:   12
        case .afternoon: 13
        case .evening:   16
        default:         14
        }
    }

    /// Ce qu'on aurait à dire en milieu de journée — ou `nil` pour se taire.
    /// L'ordre compte : ce qui est utile passe avant ce qui est gentil.
    var middayNudge: Nudge? {
        guard isOnboarded else { return nil }

        // Une échéance demain qu'on n'a pas prise aujourd'hui : c'est le plus
        // utile qu'on puisse dire.
        let cal = Calendar.current
        if let soon = items.first(where: { item in
            guard item.isOpen, !item.isPickedToday, let due = item.due else { return false }
            return cal.isDateInTomorrow(due)
        }) {
            return .deadlineTomorrow(soon.title)
        }

        let picks = pickedToday
        if picks.isEmpty {
            // Rien de choisi, mais il faut avoir de quoi choisir.
            return items.contains(where: \.isOpen) ? .nothingPicked : nil
        }

        let open = picks.filter(\.isOpen)
        switch open.count {
        case 0:  return .bothDone
        case 1 where picks.count > 1: return .oneLeft(open[0].title.lowercased())
        default: return .notStarted(open[0].title)
        }
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
        // Repose les rappels au cas où l'heure de coucher a changé.
        if remindersOn {
            let (h, m) = eveningReminderTime
            Task {
                await Reminders.enable(eveningHour: h, eveningMinute: m)
                refreshMiddayNudge()
            }
        }
    }

    private func restore() {
        guard let saved = Store.load() else { return }

        name = saved.name
        isOnboarded = saved.isOnboarded
        energyMoment = saved.energyMoment
        dailyStruggle = saved.dailyStruggle
        goodDay = saved.goodDay
        if let period = saved.energyMoment?.period { life.selfReportedPeriod = period }
        tab = saved.tab
        items = saved.items
        deadlines = saved.deadlines
        capturedThoughts = saved.capturedThoughts
        dayNotes = saved.dayNotes ?? []
        eveningDoneOn = saved.eveningDoneOn
        remindersOn = saved.remindersOn ?? false
        life.lastMood = saved.lastMood
        life.targetBedtime = saved.targetBedtime

        if Calendar.current.isDateInToday(saved.savedAt) {
            screen = saved.screen
        } else {
            screen = isOnboarded ? .wakeUp : .welcome
            tab = .today
        }

        if screen == .triage {
            triagePicks = Planner.suggestions(from: items, struggle: dailyStruggle).map(\.item.id)
        }
    }

    private func persist() {
        guard isReady else { return }
        Store.save(StoredState(
            name: name,
            isOnboarded: isOnboarded,
            energyMoment: energyMoment,
            dailyStruggle: dailyStruggle,
            goodDay: goodDay,
            screen: screen,
            tab: tab,
            items: items,
            deadlines: deadlines,
            capturedThoughts: capturedThoughts,
            dayNotes: dayNotes,
            eveningDoneOn: eveningDoneOn,
            remindersOn: remindersOn,
            lastMood: life.lastMood,
            targetBedtime: life.targetBedtime,
            savedAt: Date()
        ))
    }

    // MARK: - Onboarding

    func completeOnboarding(name raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { name = trimmed }
        go(to: .attune)
    }

    /// Range les trois réponses et termine le premier lancement.
    func completeAttune(energy: EnergyMoment, struggle: DailyStruggle, goodDay: GoodDay) {
        energyMoment = energy
        dailyStruggle = struggle
        self.goodDay = goodDay
        life.selfReportedPeriod = energy.period
        isOnboarded = true
        remindersOn = true   // deux rappels par jour : matin, soir
        go(to: .wakeUp)
    }

    // MARK: - Bilan du soir

    /// Transitoire : « plus tard » ce soir, on ne redemande pas avant relance.
    private var eveningSnoozed = false

    /// À l'ouverture / au retour au premier plan : est-ce l'heure du bilan ?
    func checkForEvening() {
        guard isOnboarded, screen == .app, !eveningSnoozed else { return }
        guard !Calendar.current.isDateInToday(eveningDoneOn ?? .distantPast) else { return }
        guard Calendar.current.component(.hour, from: Date()) >= 18 else { return }
        guard !pickedToday.isEmpty else { return }   // rien à passer en revue
        go(to: .evening)
    }

    /// « Plus tard » : on retourne dans l'app sans nagger avant relance.
    func snoozeEvening() {
        eveningSnoozed = true
        withAnimation(.easeInOut(duration: 0.3)) { screen = .app }
    }

    // MARK: - Le mot du milieu de journée

    /// Repose le mot du milieu d'après l'état du moment. Appelé quand l'app
    /// passe en arrière-plan : le contenu colle ainsi toujours à la journée.
    /// S'il n'y a rien d'utile à dire, on ne sonne pas.
    func refreshMiddayNudge() {
        guard remindersOn else {
            Reminders.scheduleMidday(nil, hour: 0, minute: 0)
            return
        }
        Reminders.scheduleMidday(middayNudge, hour: middayReminderHour, minute: 0)
    }

    /// Referme la journée. Ce qui n'est pas fini repart dans le tri de demain
    /// tout seul (le Planner lui donne un bonus de continuité).
    func completeEvening(mood: Mood?, mattered: String) {
        if let mood { life.lastMood = mood }
        let done = pickedToday.filter { !$0.isOpen }.count
        dayNotes.append(DayNote(
            mood: mood,
            mattered: mattered.trimmingCharacters(in: .whitespacesAndNewlines),
            closedCount: done
        ))
        eveningDoneOn = Date()
        withAnimation(.easeInOut(duration: 0.4)) { screen = .app }
    }

    /// Marque / démarque une chose depuis le bilan.
    func toggleDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].doneAt = items[index].isOpen ? Date() : nil
    }

    // MARK: - Démo

    /// Bouton provisoire : efface tout et repart de l'écran d'accueil.
    func resetAll() {
        Store.clear()
        name = "Léa"
        isOnboarded = false
        energyMoment = nil
        dailyStruggle = nil
        goodDay = nil
        tab = .today
        inFocus = false
        isListening = false
        life = .sample
        capturedThoughts = []
        dayNotes = []
        eveningDoneOn = nil
        remindersOn = false
        Reminders.disable()
        items = Item.starter
        deadlines = Deadline.starter
        triagePicks = []
        withAnimation(.easeInOut(duration: 0.4)) { screen = .welcome }
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
        triagePicks = Planner.suggestions(from: items, struggle: dailyStruggle).map(\.item.id)
        go(to: .triage)
    }

    /// La raison affichée sous une suggestion, s'il y en a une.
    func triageReason(for id: UUID) -> String? {
        Planner.suggestions(from: items, struggle: dailyStruggle).first { $0.item.id == id }?.reason
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
        let suggested = Set(Planner.suggestions(from: items, struggle: dailyStruggle).map(\.item.id))
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
