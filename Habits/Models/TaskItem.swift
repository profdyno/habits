import Foundation

struct TaskItem: Identifiable {
    let id: String              // calendarItemIdentifier
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let listName: String
}

struct ReminderListInfo: Identifiable {
    let id: String
    let title: String
}
