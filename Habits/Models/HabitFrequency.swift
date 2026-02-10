import Foundation

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var listName: String {
        switch self {
        case .daily: return "Habits-Daily"
        case .weekly: return "Habits-Weekly"
        case .monthly: return "Habits-Monthly"
        }
    }

    var summaryPeriodCount: Int {
        switch self {
        case .daily: return 7
        case .weekly: return 4
        case .monthly: return 3
        }
    }
}
