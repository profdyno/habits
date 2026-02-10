import Foundation

enum DateHelpers {
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    /// Returns 14 DayColumns: previous Monday through current Sunday.
    static func computeDayColumns() -> [DayColumn] {
        let cal = calendar
        let today = cal.startOfDay(for: Date())

        // Find the Monday of the current week
        let currentWeekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        // days since Monday: (currentWeekday - 2 + 7) % 7
        let daysSinceMonday = (currentWeekday - 2 + 7) % 7
        guard let currentMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return []
        }

        // Previous Monday is 7 days before current Monday
        guard let previousMonday = cal.date(byAdding: .day, value: -7, to: currentMonday) else {
            return []
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        var columns: [DayColumn] = []
        for i in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: i, to: previousMonday) else { continue }
            let startOfDate = cal.startOfDay(for: date)
            columns.append(DayColumn(
                id: startOfDate,
                label: dayFormatter.string(from: date),
                dateLabel: dateFormatter.string(from: date),
                isToday: cal.isDate(date, inSameDayAs: today),
                isFuture: startOfDate > today
            ))
        }

        return columns
    }

    /// Returns the last 7 dates ending with today (start-of-day).
    static func lastSevenDays() -> [Date] {
        let cal = calendar
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: -(6 - offset), to: today)
        }
    }

    /// Normalizes a date to start-of-day for use as a key.
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
