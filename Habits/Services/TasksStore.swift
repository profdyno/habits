import Foundation

enum TasksStore {
    private static let key = "tasks_selected_list_ids"

    static func loadSelectedListIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func saveSelectedListIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: key)
    }
}
