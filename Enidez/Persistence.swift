//
//  Persistence.swift
//  Enidez
//
//  Sauvegarde légère de l'état entre deux lancements : les deux choses du jour,
//  l'humeur, l'objectif de coucher, et l'endroit où on en était.
//  Rien de sensible, donc UserDefaults suffit — pas de base de données.
//
//  « Un jour » : à un jour de distance, on repart du début, les tâches
//  reprennent à zéro. Le même jour, on retrouve exactement son fil.
//

import Foundation

/// Instantané sérialisable de ce qui compte d'un lancement à l'autre.
struct StoredState: Codable {
    var screen: Screen
    var tasks: [DayTask]
    var lastMood: Mood?
    var targetBedtime: Date
    var savedAt: Date
}

enum Store {
    private static let key = "enidez.state.v1"

    /// Relit l'état sauvegardé, ou `nil` s'il n'y en a pas (ou s'il est illisible).
    static func load() -> StoredState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }

    /// Écrit l'état. Silencieux en cas d'échec : une sauvegarde ratée ne doit
    /// jamais gêner l'utilisation.
    static func save(_ state: StoredState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
