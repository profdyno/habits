import Foundation

enum NoteStore {
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
        let dir = containerURL()
        let url = dir.appendingPathComponent("\(key).md")
        if FileManager.default.fileExists(atPath: url.path) {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        // New week — seed from previous week's file
        let prev = previousKey(for: key)
        let prevURL = dir.appendingPathComponent("\(prev).md")
        if FileManager.default.fileExists(atPath: prevURL.path),
           let content = try? String(contentsOf: prevURL, encoding: .utf8), !content.isEmpty {
            save(key: key, content: content)
            return content
        }
        return ""
    }

    static func save(key: String, content: String) {
        let dir = containerURL()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(key).md")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Returns the key for the previous week (7 days earlier).
    private static func previousKey(for key: String) -> String {
        let dateString = String(key.dropFirst(4)) // strip "ELT-"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: dateString),
              let prev = Calendar.current.date(byAdding: .day, value: -7, to: date) else {
            return ""
        }
        return "ELT-\(formatter.string(from: prev))"
    }

    private static func containerURL() -> URL {
        if let icloud = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            return icloud
        }
        // Fallback to local documents if iCloud is unavailable
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
