//
//  VoiceInterpreter.swift
//  Enidez
//
//  Traduit une phrase dite ou écrite en `Item` : un titre, une estimation de
//  durée si elle est donnée, une échéance si une date est mentionnée.
//  La date passe par `NSDataDetector`, qui comprend « mardi prochain »,
//  « le 21 », « demain », « dans trois jours »… dans la langue de l'appareil.
//  La règle : ne jamais laisser une phrase sans effet.
//

import Foundation

enum VoiceInterpreter {

    /// « Appeler le plombier, cinq minutes » → titre + durée.
    /// « Rendez-vous kiné mardi prochain » → titre + échéance.
    static func item(from phrase: String) -> Item {
        var rest = phrase
        var minutes: Int?
        var due: Date?

        if let (value, range) = firstDuration(in: rest) {
            minutes = value
            rest.removeSubrange(range)
        }
        if let (date, range) = firstDate(in: rest) {
            due = date
            rest.removeSubrange(range)
        }
        let title = tidyTitle(stripIntent(rest))
        return Item(title: title.isEmpty ? tidyTitle(stripIntent(phrase)) : capitalizedFirst(title),
                    minutes: minutes,
                    due: due)
    }

    // MARK: - Date

    private static func firstDate(in phrase: String) -> (Date, Range<String.Index>)? {
        if let relative = frenchRelativeDate(in: phrase) { return relative }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let ns = phrase as NSString
        let match = detector.firstMatch(in: phrase, range: NSRange(location: 0, length: ns.length))
        guard let match, var date = match.date,
              let range = Range(match.range, in: phrase) else { return nil }

        // Une date passée veut dire « la prochaine fois ». Mais la prochaine
        // fois n'est pas la même chose selon ce qui a été dit : un jour de la
        // semaine (« mardi ») revient dans sept jours ; une date du calendrier
        // (« le 21 juillet ») revient l'an prochain.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if date < today {
            if namesWeekdayOnly(String(phrase[range])) {
                var guardCount = 0
                while date < today && guardCount < 8 {
                    date = cal.date(byAdding: .day, value: 7, to: date) ?? date
                    guardCount += 1
                }
            } else {
                var guardCount = 0
                while date < today && guardCount < 3 {
                    date = cal.date(byAdding: .year, value: 1, to: date) ?? date
                    guardCount += 1
                }
            }
        }
        return (date, range)
    }

    /// Vrai quand le fragment reconnu ne nomme qu'un jour de la semaine,
    /// sans quantième ni mois — « mardi », « vendredi prochain ».
    private static func namesWeekdayOnly(_ fragment: String) -> Bool {
        let f = fold(fragment)
        guard !f.contains(where: \.isNumber) else { return false }
        let weekdays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        return weekdays.contains { f.contains($0) }
    }

    /// Ce que `NSDataDetector` ne sait pas faire en français : « demain »,
    /// « après-demain », « dans trois jours », « dans une semaine ».
    private static func frenchRelativeDate(in phrase: String) -> (Date, Range<String.Index>)? {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()

        if let r = phrase.range(of: #"après[- ]demain"#, options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
            return (cal.date(byAdding: .day, value: 2, to: noon) ?? noon, r)
        }
        if let r = phrase.range(of: #"\bdemain\b"#, options: [.regularExpression, .caseInsensitive]) {
            return (cal.date(byAdding: .day, value: 1, to: noon) ?? noon, r)
        }
        if let r = phrase.range(of: #"dans (une|1) semaines?"#, options: [.regularExpression, .caseInsensitive]) {
            return (cal.date(byAdding: .day, value: 7, to: noon) ?? noon, r)
        }
        let words: [String: Int] = ["deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7]
        let names = words.keys.joined(separator: "|")
        if let r = phrase.range(of: "dans (\\d{1,2}|\(names)) jours?",
                                options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
            let token = fold(phrase[r].split(separator: " ")[1].description)
            let n = Int(token) ?? words[token] ?? 1
            return (cal.date(byAdding: .day, value: n, to: noon) ?? noon, r)
        }
        return nil
    }

    /// « JEU 21 » à partir d'une date.
    static func shortLabel(_ date: Date) -> String {
        let days = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"]
        let comps = Calendar.current.dateComponents([.weekday, .day], from: date)
        let short = days[(comps.weekday ?? 1) - 1]
        return "\(short) \(comps.day ?? 0)"
    }

    // MARK: - Durée

    private static func firstDuration(in phrase: String) -> (minutes: Int, range: Range<String.Index>)? {
        let named: [(String, Int)] = [
            ("trois quarts d'heure", 45), ("trois quarts d heure", 45),
            ("quart d'heure", 15), ("quart d heure", 15),
            ("demi-heure", 30), ("demie heure", 30), ("demi heure", 30),
            ("une heure", 60),
        ]
        for (needle, value) in named {
            if let r = phrase.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
                return (value, r)
            }
        }
        if let r = phrase.range(of: #"\d{1,3}\s*(minutes?|min)\b"#,
                                options: [.regularExpression, .caseInsensitive]) {
            let digits = phrase[r].prefix { $0.isNumber }
            if let value = Int(digits) { return (value, r) }
        }
        let names = numberWords.keys.joined(separator: "|")
        if let r = phrase.range(of: "\\b(\(names))\\s+minutes?\\b",
                                options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
            let word = fold(phrase[r].prefix { $0 != " " }.description)
            if let value = numberWords[word] { return (value, r) }
        }
        return nil
    }

    private static let numberWords: [String: Int] = [
        "cinq": 5, "dix": 10, "quinze": 15, "vingt": 20,
        "trente": 30, "quarante": 40, "cinquante": 50, "soixante": 60
    ]

    // MARK: - Nettoyage

    /// Retire un verbe d'intention en tête (« rappelle-moi », « note », « penser à »).
    private static func stripIntent(_ text: String) -> String {
        let openers = [
            #"^\s*rappelle[- ]moi( de| d'| que)?\s+"#,
            #"^\s*n'oublie pas( de| d')?\s+"#,
            #"^\s*pense(r)?( à| a| au| aux)?\s+"#,
            #"^\s*note(r)?( de| d')?\s+"#,
            #"^\s*ajoute(r)?( de| d')?\s+"#,
            #"^\s*il faut( que je| )?\s*"#,
        ]
        var s = text
        for pattern in openers {
            s = s.replacingOccurrences(of: pattern, with: "",
                                       options: [.regularExpression, .caseInsensitive])
        }
        return s
    }

    private static func tidyTitle(_ text: String) -> String {
        var s = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-—'’"))

        let fillers: Set<String> = ["pendant", "en", "pour", "de", "d", "un", "une", "environ",
                                    "le", "la", "prochain", "prochaine", "ce", "cette", "avant", "à", "a"]
        var changed = true
        while changed {
            changed = false
            for edge in [true, false] {
                let parts = s.split(separator: " ").map(String.init)
                guard let candidate = edge ? parts.last : parts.first,
                      fillers.contains(fold(candidate)) else { continue }
                s = (edge ? parts.dropLast() : parts.dropFirst())
                    .joined(separator: " ")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-—'’"))
                changed = true
            }
        }
        return s
    }

    private static func fold(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?—-'’"))
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
