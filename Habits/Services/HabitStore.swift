import Foundation

enum HabitStore {
    private static func key(for frequency: HabitFrequency) -> String {
        "habit_order_\(frequency.rawValue)"
    }

    static func loadOrder(for frequency: HabitFrequency) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(for: frequency)) ?? []
    }

    static func saveOrder(_ names: [String], for frequency: HabitFrequency) {
        UserDefaults.standard.set(names, forKey: key(for: frequency))
    }
}
