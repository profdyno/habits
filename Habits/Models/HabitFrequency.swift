import Foundation

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case tasks, daily, weekly, monthly, notes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tasks: return "Tasks"
        case .daily: return "Habits-Daily"
        case .weekly: return "Habits-Weekly"
        case .monthly: return "Habits-Quarterly"
        case .notes: return "Notes"
        }
    }

    var listName: String {
        switch self {
        case .daily: return "Habits-Daily"
        case .weekly: return "Habits-Weekly"
        case .monthly: return "Habits-Monthly"
        case .tasks, .notes: return ""
        }
    }

    var columnCount: Int {
        switch self {
        case .daily: return 21
        case .weekly: return 14
        case .monthly: return 13
        case .tasks: return 7
        case .notes: return 0
        }
    }

    /// Rolling window for per-habit overall % calculation.
    var rollingPeriodCount: Int {
        switch self {
        case .daily: return 14
        case .weekly: return 13
        case .monthly: return 12
        case .tasks: return 7
        case .notes: return 0
        }
    }
}
