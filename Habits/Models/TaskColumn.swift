import Foundation

struct TaskColumn: Identifiable {
    let id: String           // "delinquent", "mon", "tue", etc.
    let startDate: Date?     // nil for delinquent
    let endDate: Date?       // same as startDate for weekdays; Sunday end for weekend
    let label: String        // "Feb 10" or "Feb 15-16" or "Delinquent"
    let dayLabel: String     // "Mon", "Sat/Sun", "Late"
    let isToday: Bool
    let isDelinquent: Bool
}
