import Foundation

enum NoteStore {
    private static let iCloudStore = NSUbiquitousKeyValueStore.default

    /// Key based on next Monday's date (or today if Monday): "ELT-20260216"
    /// A new note is created each Tuesday when the next Monday shifts forward.
    static func todayKey() -> String {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        // Days until next Monday: (2 - weekday + 7) % 7, but 0 if already Monday
        let daysUntilMonday = (2 - weekday + 7) % 7
        let nextMonday = cal.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "ELT-\(formatter.string(from: nextMonday))"
    }

    static func load(key: String) -> String {
        // Try iCloud first, fall back to local
        if let value = iCloudStore.string(forKey: key) {
            return value
        }
        return UserDefaults.standard.string(forKey: "note_\(key)") ?? ""
    }

    static func save(key: String, content: String) {
        UserDefaults.standard.set(content, forKey: "note_\(key)")
        iCloudStore.set(content, forKey: key)
        iCloudStore.synchronize()
    }
}
