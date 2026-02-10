import Foundation

enum HabitStore {
    private static let key = "habits_list"

    static func loadHabits() -> [Habit] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let habits = try? JSONDecoder().decode([Habit].self, from: data) else {
            return []
        }
        return habits
    }

    static func saveHabits(_ habits: [Habit]) {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
