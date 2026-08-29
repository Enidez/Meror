//
//  VoiceInterpreter.swift
//  Enidez
//
//  Traduit une phrase dite à voix haute en action concrète. Volontairement
//  simple : quelques repères de durée et de jour, le reste devient le titre.
//  La règle : ne jamais laisser une phrase sans effet, quitte à être approximatif.
//

import Foundation

enum VoiceInterpreter {

    /// « Appeler le plombier, cinq minutes » → titre + durée.
    static func task(from phrase: String) -> DayTask {
        var title = phrase
        var minutes: Int?

        if let (value, range) = firstDuration(in: phrase) {
            minutes = value
            title.removeSubrange(range)
        }
        title = tidyTitle(title)
        return DayTask(title: title.isEmpty ? tidyTitle(phrase) : title,
                       minutes: minutes ?? 10)
    }

    /// « Jeudi 21, penser au dentiste » → « JEU 21 · Penser au dentiste ».
    static func deadline(from phrase: String) -> Deadline {
        var words = phrase.split { $0 == " " || $0 == "," || $0 == "\n" }.map(String.init)
        var label = "BIENTÔT"

        if let first = words.first, let short = dayShort[fold(first)] {
            words.removeFirst()
            if let next = words.first, next.allSatisfy(\.isNumber) {
                label = "\(short) \(next)"
                words.removeFirst()
            } else {
                label = short
            }
        }
        let title = tidyTitle(words.joined(separator: " "))
        return Deadline(day: label, title: title.isEmpty ? phrase : capitalizedFirst(title))
    }

    // MARK: - Durée

    /// Cherche une expression de durée dans la phrase et renvoie sa valeur en
    /// minutes + la portion de texte à retirer du titre.
    private static func firstDuration(in phrase: String) -> (minutes: Int, range: Range<String.Index>)? {
        let named: [(String, Int)] = [
            ("trois quarts d'heure", 45),
            ("trois quarts d heure", 45),
            ("quart d'heure", 15),
            ("quart d heure", 15),
            ("demi-heure", 30),
            ("demie heure", 30),
            ("demi heure", 30),
            ("une heure", 60),
        ]
        for (needle, value) in named {
            if let r = phrase.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
                return (value, r)
            }
        }

        // « 15 minutes », « 10 min »
        if let r = phrase.range(of: #"\d{1,3}\s*(minutes?|min)\b"#,
                                options: [.regularExpression, .caseInsensitive]) {
            let digits = phrase[r].prefix { $0.isNumber }
            if let value = Int(digits) { return (value, r) }
        }

        // « cinq minutes »
        let names = numberWords.keys.joined(separator: "|")
        if let r = phrase.range(of: "\\b(\(names))\\s+minutes?\\b",
                                options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
            let word = fold(phrase[r].prefix { $0 != " " } .description)
            if let value = numberWords[word] { return (value, r) }
        }
        return nil
    }

    private static let numberWords: [String: Int] = [
        "cinq": 5, "dix": 10, "quinze": 15, "vingt": 20,
        "trente": 30, "quarante": 40, "cinquante": 50, "soixante": 60
    ]

    // MARK: - Jour

    private static let dayShort: [String: String] = [
        "lundi": "LUN", "mardi": "MAR", "mercredi": "MER", "jeudi": "JEU",
        "vendredi": "VEN", "samedi": "SAM", "dimanche": "DIM"
    ]

    // MARK: - Nettoyage

    /// Retire la ponctuation de bord et les petits mots de liaison laissés
    /// par le découpage (« pendant », « un », « de »…), puis recolle proprement.
    private static func tidyTitle(_ text: String) -> String {
        var s = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-—'’"))

        let fillers: Set<String> = ["pendant", "en", "pour", "de", "d", "un", "une", "environ"]
        var changed = true
        while changed {
            changed = false
            for edge in [true, false] {  // fin de phrase, puis début
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

    /// Sans accents, minuscules, sans ponctuation de bord.
    private static func fold(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?—-'’"))
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
