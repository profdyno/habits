import Foundation

enum DateHelpers {
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    /// Returns DayColumns spanning `weeks` weeks (default 2), ending at the current Sunday.
    static func computeDayColumns(weeks: Int = 2) -> [DayColumn] {
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

        // Start Monday is (weeks - 1) weeks before current Monday
        guard let startMonday = cal.date(byAdding: .day, value: -(weeks - 1) * 7, to: currentMonday) else {
            return []
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        let totalDays = weeks * 7
        var columns: [DayColumn] = []
        for i in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: i, to: startMonday) else { continue }
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

    /// Returns DayColumns for weekly view — one column per week.
    /// `count` weeks ending with the current week. id = Monday of that week.
    static func computeWeekColumns(count: Int = 14) -> [DayColumn] {
        let cal = calendar
        let today = cal.startOfDay(for: Date())

        let currentWeekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (currentWeekday - 2 + 7) % 7
        guard let currentMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return []
        }

        var columns: [DayColumn] = []
        for i in stride(from: -(count - 1), through: 0, by: 1) {
            guard let monday = cal.date(byAdding: .weekOfYear, value: i, to: currentMonday) else { continue }
            let startOfMonday = cal.startOfDay(for: monday)
            let weekOfYear = cal.component(.weekOfYear, from: monday)
            let isCurrentWeek = (i == 0)
            // A week is "future" only if the Monday is after today
            let isFuture = startOfMonday > today
            columns.append(DayColumn(
                id: startOfMonday,
                label: "W\(weekOfYear)",
                dateLabel: "",
                isToday: isCurrentWeek,
                isFuture: isFuture
            ))
        }

        return columns
    }

    /// Returns DayColumns for monthly view — one column per month.
    /// `count` months ending with the current month. id = 1st of that month.
    static func computeMonthColumns(count: Int = 13) -> [DayColumn] {
        let cal = calendar
        let today = cal.startOfDay(for: Date())

        guard let currentFirst = cal.date(from: cal.dateComponents([.year, .month], from: today)) else {
            return []
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        var columns: [DayColumn] = []
        for i in stride(from: -(count - 1), through: 0, by: 1) {
            guard let firstOfMonth = cal.date(byAdding: .month, value: i, to: currentFirst) else { continue }
            let startOfFirst = cal.startOfDay(for: firstOfMonth)
            let isCurrentMonth = (i == 0)
            let isFuture = startOfFirst > today
            columns.append(DayColumn(
                id: startOfFirst,
                label: monthFormatter.string(from: firstOfMonth),
                dateLabel: "",
                isToday: isCurrentMonth,
                isFuture: isFuture
            ))
        }

        return columns
    }

    /// Normalizes a date to the start of its period for the given frequency.
    static func periodStart(for date: Date, frequency: HabitFrequency) -> Date {
        let cal = calendar
        switch frequency {
        case .daily:
            return cal.startOfDay(for: date)
        case .weekly:
            let weekday = cal.component(.weekday, from: date)
            let daysSinceMonday = (weekday - 2 + 7) % 7
            guard let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: date) else {
                return cal.startOfDay(for: date)
            }
            return cal.startOfDay(for: monday)
        case .monthly:
            guard let first = cal.date(from: cal.dateComponents([.year, .month], from: date)) else {
                return cal.startOfDay(for: date)
            }
            return cal.startOfDay(for: first)
        }
    }

    /// Returns the last N period-start dates ending with the current period.
    static func lastPeriods(frequency: HabitFrequency, count: Int) -> [Date] {
        let cal = calendar
        let today = Date()
        let currentPeriod = periodStart(for: today, frequency: frequency)

        return (0..<count).compactMap { offset in
            switch frequency {
            case .daily:
                return cal.date(byAdding: .day, value: -(count - 1 - offset), to: currentPeriod)
            case .weekly:
                return cal.date(byAdding: .weekOfYear, value: -(count - 1 - offset), to: currentPeriod)
            case .monthly:
                return cal.date(byAdding: .month, value: -(count - 1 - offset), to: currentPeriod)
            }
        }
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
