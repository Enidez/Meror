//
//  LifeContext.swift
//  Enidez
//
//  Ce que l'assistant sait de toi pour te conseiller : sommeil, activité,
//  rythme de focus, humeur. La complexité reste côté machine : l'écran ne
//  montre qu'une observation bienveillante et un conseil actionnable.
//

import Foundation

/// Un état ressenti, capté rapidement (à la voix ou d'un geste).
enum Mood: String, CaseIterable, Identifiable, Codable {
    case good = "En forme"
    case ok = "Ça va"
    case low = "Difficile"

    var id: String { rawValue }
}

/// Le moment de la journée où le focus réussit le mieux.
enum FocusPeriod {
    case morning, afternoon, evening

    /// Formulation positive : « les matins ».
    var label: String {
        switch self {
        case .morning: "les matins"
        case .afternoon: "les après-midis"
        case .evening: "les soirées"
        }
    }

    /// Le moment qui réussit le moins, en contraste.
    var complement: String {
        switch self {
        case .morning: "les fins d'après-midi"
        case .afternoon: "les débuts de matinée"
        case .evening: "les matins"
        }
    }
}

/// L'ensemble des paramètres de vie connus par l'assistant.
struct LifeContext {
    // Sommeil
    var lastNightSleepHours: Double?
    var averageSleepHours: Double?
    var averageBedtime: Date?

    // Activité & énergie
    var stepsToday: Int?
    var activeEnergyToday: Double?   // kcal

    // Rythme de focus
    var bestFocusPeriod: FocusPeriod = .morning
    /// Le moment déclaré au premier lancement, avant qu'on ait pu l'observer.
    var selfReportedPeriod: FocusPeriod?
    var focusStreakDays: Int = 0
    var focusHoursThisWeek: Double = 0
    var thingsClosedThisWeek: Int = 0

    // Humeur
    var lastMood: Mood?

    // Préférences (le petit profil qui complète Santé)
    var targetBedtime: Date = LifeContext.time(23, 0)

    /// Vrai quand les données viennent réellement d'Apple Santé.
    var healthConnected: Bool = false

    /// Construit une heure du jour (aujourd'hui) à partir de heures/minutes.
    static func time(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// Données d'exemple, cohérentes avec le récit du design, utilisées tant
    /// qu'Apple Santé n'est pas connecté.
    static let sample = LifeContext(
        lastNightSleepHours: 6.2,
        averageSleepHours: 6.8,
        averageBedtime: time(23, 40),
        stepsToday: 3200,
        activeEnergyToday: 180,
        bestFocusPeriod: .morning,
        focusStreakDays: 0,
        focusHoursThisWeek: 0,
        thingsClosedThisWeek: 0,
        lastMood: nil,
        targetBedtime: time(23, 0),
        healthConnected: false
    )
}

/// Le mot du jour quand tout est fait : un label discret, une phrase, et
/// parfois l'auteur d'un livre.
struct RestingNote {
    var label: String?
    var text: String
    var footnote: String?
}

/// Traduit les paramètres de vie en phrases : le ton est neutre et efficace,
/// mais bienveillant. Jamais de score, jamais de reproche.
enum AdviceEngine {

    /// Sous-titre du réveil, adapté à la nuit passée.
    static func wakeUpSubtitle(_ c: LifeContext) -> String {
        guard let sleep = c.lastNightSleepHours else {
            return "Prends le temps pour toi, loin du bruit."
        }
        let formatted = hours(sleep)
        switch sleep {
        case ..<6:
            return "Nuit courte, \(formatted). On y va tout en douceur."
        case 7.5...:
            return "Belle nuit, \(formatted). Tu peux attaquer en confiance."
        default:
            return "\(formatted) cette nuit. Prends le temps pour toi."
        }
    }

    /// Observation d'ouverture de l'onglet « Toi », en deux tons. La seconde
    /// phrase n'apparaît que si on a vraiment observé un rythme.
    static func observation(_ c: LifeContext) -> (lead: String, tail: String) {
        let tail: String
        if c.focusStreakDays > 0 {
            tail = "Tes \(c.bestFocusPeriod.label) te réussissent mieux que \(c.bestFocusPeriod.complement)."
        } else if let p = c.selfReportedPeriod {
            tail = "Tu m'as dit tenir mieux \(p.label). J'en tiens compte."
        } else {
            tail = ""
        }
        if c.lastMood == .low {
            return ("Aujourd'hui pèse un peu plus, et c'est ok.", tail)
        }
        let lead = c.focusStreakDays > 0
            ? "Tu tiens ton rythme depuis \(c.focusStreakDays) jours."
            : "On apprend à se connaître. Encore quelques jours."
        return (lead, tail)
    }

    /// Le conseil actionnable, choisi selon ce qui compte le plus maintenant.
    static func advice(_ c: LifeContext) -> String {
        if let bedtime = c.averageBedtime,
           minutesOfDay(bedtime) > minutesOfDay(c.targetBedtime) + 15 {
            return "Coucher avant \(clock(c.targetBedtime)) cette semaine. Tes \(c.bestFocusPeriod.label) portent presque tout ton focus."
        }
        if let steps = c.stepsToday, steps < 4000 {
            return "Une marche aujourd'hui t'aiderait à relâcher. Ton corps réclame un peu de mouvement."
        }
        if let sleep = c.averageSleepHours, sleep < 6.5 {
            return "Vise une demi-heure de sommeil en plus. Tes nuits sont un peu courtes en ce moment."
        }
        return "Garde ce rythme. Ce que tu fais en ce moment te réussit."
    }

    /// La ligne de chiffres, reléguée en fin d'écran, en petit. Vrais compteurs.
    static func summaryLine(closedThisWeek: Int) -> String {
        switch closedThisWeek {
        case 0:  return "Rien de bouclé cette semaine pour l'instant."
        case 1:  return "1 chose bouclée cette semaine."
        default: return "\(closedThisWeek) choses bouclées cette semaine."
        }
    }

    /// Ce qu'on montre quand la journée est faite : une phrase pour toi, une
    /// petite idée, ou un livre — choisi selon le moment, stable pour la
    /// journée (rien qui bouge, rien d'aléatoire à l'écran).
    static func restingNote(_ c: LifeContext, on date: Date = Date()) -> RestingNote {
        if c.lastMood == .low {
            return RestingNote(
                label: "POUR TOI",
                text: "Journée plus lourde. Tu n'as pas à la remplir. T'être arrêtée ici, c'est déjà quelque chose.")
        }
        if c.focusStreakDays >= 10 {
            return RestingNote(
                label: "POUR TOI",
                text: "\(c.focusStreakDays) jours que tu tiens ton rythme. Ça ne se voit pas de l'extérieur, mais c'est rare. Savoure-le.")
        }

        let pool: [RestingNote] = [
            RestingNote(label: "UNE IDÉE",
                        text: "Sors marcher dix minutes, sans téléphone. Ton corps a fait sa part, offre-lui de l'air."),
            RestingNote(label: "UN LIVRE",
                        text: "« Méditer, jour après jour »", footnote: "Christophe André"),
            RestingNote(label: "UNE IDÉE",
                        text: "Écris à quelqu'un à qui tu penses depuis un moment. Deux lignes suffisent."),
            RestingNote(label: "UN LIVRE",
                        text: "« Un petit pas peut changer votre vie »", footnote: "Robert Maurer"),
            RestingNote(label: nil,
                        text: "Ce que tu fais en ce moment te réussit. Garde ce rythme, sans forcer."),
            RestingNote(label: "UNE IDÉE",
                        text: "Range une seule chose qui traîne. Une. Puis laisse le reste tranquille."),
            RestingNote(label: "UN LIVRE",
                        text: "« L'éloge de la lenteur »", footnote: "Carl Honoré"),
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return pool[day % pool.count]
    }

    // MARK: - Mise en forme

    /// « 6.4 » → « 6 h 24 ».
    static func hours(_ value: Double) -> String {
        let h = Int(value)
        let m = Int((value - Double(h)) * 60 + 0.5)
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    /// Heure d'horloge : « 23 h » ou « 23 h 40 ».
    static func clock(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    private static func minutesOfDay(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
