import Foundation

struct DayColumn: Identifiable {
    let id: Date
    let label: String      // e.g. "Mon"
    let dateLabel: String   // e.g. "3"
    let isToday: Bool
    let isFuture: Bool
}
