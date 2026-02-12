import Foundation

struct ParsedTaskInput {
    var title: String
    var dueDate: Date?
    var listName: String?
    var listId: String?
}

enum TaskInputParser {
    static func parse(
        _ input: String,
        availableLists: [ReminderListInfo],
        referenceDate: Date = Date()
    ) -> ParsedTaskInput {
        var remaining = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var listName: String?
        var listId: String?

        // 1. Strip " in <list>" suffix — longest match wins
        let sortedLists = availableLists.sorted { $0.title.count > $1.title.count }
        for list in sortedLists {
            let suffix = " in \(list.title)"
            if remaining.lowercased().hasSuffix(suffix.lowercased()) {
                listName = list.title
                listId = list.id
                remaining = String(remaining.dropLast(suffix.count))
                break
            }
        }

        // 2. Extract date
        let cal = Calendar.current
        var dueDate: Date? = nil

        // Relative dates
        let relativePatterns: [(pattern: String, offset: Int)] = [
            ("today", 0),
            ("tomorrow", 1),
        ]
        for (word, offset) in relativePatterns {
            if let range = remaining.range(of: "\\b\(word)\\b", options: [.regularExpression, .caseInsensitive]) {
                dueDate = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: referenceDate))
                remaining = remaining.replacingCharacters(in: range, with: "")
                break
            }
        }

        // Day names: "on Friday" or just "Friday"
        if dueDate == nil {
            let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            // Try "on <day>" first, then bare "<day>"
            for (index, dayName) in dayNames.enumerated() {
                let patterns = ["\\bon\\s+\(dayName)\\b", "\\b\(dayName)\\b"]
                for pattern in patterns {
                    if let range = remaining.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                        dueDate = nextWeekday(index + 1, after: referenceDate, calendar: cal)
                        remaining = remaining.replacingCharacters(in: range, with: "")
                        break
                    }
                }
                if dueDate != nil { break }
            }
        }

        // Explicit dates: "Feb 17", "February 17", "2/17"
        if dueDate == nil {
            // Month name + day: "Feb 17" or "February 17"
            let monthNamePattern = "\\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\\s+(\\d{1,2})\\b"
            if let regex = try? NSRegularExpression(pattern: monthNamePattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
                let monthStr = (remaining as NSString).substring(with: match.range(at: 1))
                let dayStr = (remaining as NSString).substring(with: match.range(at: 2))
                if let month = parseMonthName(monthStr), let day = Int(dayStr) {
                    dueDate = resolveExplicitDate(month: month, day: day, referenceDate: referenceDate, calendar: cal)
                    let fullRange = Range(match.range, in: remaining)!
                    // Also strip leading "on " if present
                    let prefix = "on "
                    let startIdx = fullRange.lowerBound
                    let beforeStart = remaining[remaining.startIndex..<startIdx]
                    if beforeStart.hasSuffix(prefix) {
                        let extendedStart = remaining.index(startIdx, offsetBy: -prefix.count)
                        remaining = remaining.replacingCharacters(in: extendedStart..<fullRange.upperBound, with: "")
                    } else {
                        remaining = remaining.replacingCharacters(in: fullRange, with: "")
                    }
                }
            }

            // Numeric: "2/17"
            if dueDate == nil {
                let numericPattern = "\\b(\\d{1,2})/(\\d{1,2})\\b"
                if let regex = try? NSRegularExpression(pattern: numericPattern, options: []),
                   let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
                    let monthStr = (remaining as NSString).substring(with: match.range(at: 1))
                    let dayStr = (remaining as NSString).substring(with: match.range(at: 2))
                    if let month = Int(monthStr), let day = Int(dayStr), month >= 1, month <= 12, day >= 1, day <= 31 {
                        dueDate = resolveExplicitDate(month: month, day: day, referenceDate: referenceDate, calendar: cal)
                        let fullRange = Range(match.range, in: remaining)!
                        let startIdx = fullRange.lowerBound
                        let beforeStart = remaining[remaining.startIndex..<startIdx]
                        if beforeStart.hasSuffix("on ") {
                            let extendedStart = remaining.index(startIdx, offsetBy: -3)
                            remaining = remaining.replacingCharacters(in: extendedStart..<fullRange.upperBound, with: "")
                        } else {
                            remaining = remaining.replacingCharacters(in: fullRange, with: "")
                        }
                    }
                }
            }
        }

        // Default to today if no date parsed
        if dueDate == nil {
            dueDate = cal.startOfDay(for: referenceDate)
        }

        // 3. Clean up title
        let title = remaining
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return ParsedTaskInput(
            title: title,
            dueDate: dueDate,
            listName: listName,
            listId: listId
        )
    }

    // MARK: - Helpers

    private static func nextWeekday(_ weekday: Int, after date: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: date)
        let currentWeekday = calendar.component(.weekday, from: today)
        var daysAhead = weekday - currentWeekday
        if daysAhead <= 0 { daysAhead += 7 }
        return calendar.date(byAdding: .day, value: daysAhead, to: today)!
    }

    private static func parseMonthName(_ name: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try full name first, then abbreviation
        for format in ["MMMM", "MMM"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: name) {
                return Calendar.current.component(.month, from: date)
            }
        }
        return nil
    }

    private static func resolveExplicitDate(month: Int, day: Int, referenceDate: Date, calendar: Calendar) -> Date? {
        let year = calendar.component(.year, from: referenceDate)
        var components = DateComponents(year: year, month: month, day: day)
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate < calendar.startOfDay(for: referenceDate) {
            components.year = year + 1
            return calendar.date(from: components)
        }
        return candidate
    }
}
