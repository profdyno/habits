import EventKit
import Foundation

actor EventKitService {
    private let store = EKEventStore()
    private var habitsCalendar: EKCalendar?

    private static let listName = "Habits-Daily"

    // MARK: - Permission

    enum PermissionStatus {
        case unknown, authorized, denied
    }

    func requestAccess() async -> PermissionStatus {
        do {
            let granted = try await store.requestFullAccessToReminders()
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func currentAuthorizationStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return .authorized
        case .denied, .restricted:
            return .denied
        default:
            return .unknown
        }
    }

    // MARK: - Calendar Management

    private func findOrCreateHabitsList() throws -> EKCalendar {
        if let cached = habitsCalendar {
            // Verify it still exists
            if store.calendar(withIdentifier: cached.calendarIdentifier) != nil {
                return cached
            }
        }

        let calendars = store.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == Self.listName }) {
            habitsCalendar = existing
            return existing
        }

        let newCalendar = EKCalendar(for: .reminder, eventStore: store)
        newCalendar.title = Self.listName

        // Use the default reminder source, or fall back to local
        if let defaultSource = store.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let firstSource = store.sources.first {
            newCalendar.source = firstSource
        }

        try store.saveCalendar(newCalendar, commit: true)
        habitsCalendar = newCalendar
        return newCalendar
    }

    // MARK: - Fetch Completions

    /// Returns a dictionary mapping habit names to sets of completion dates (start-of-day).
    func fetchCompletions(
        habitNames: [String],
        startDate: Date,
        endDate: Date
    ) async throws -> [String: Set<Date>] {
        let calendar = try findOrCreateHabitsList()
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: endDate)
        let habitNameSet = Set(habitNames)

        var completions: [String: Set<Date>] = [:]
        for name in habitNames {
            completions[name] = []
        }

        for reminder in reminders {
            guard reminder.isCompleted,
                  let title = reminder.title,
                  habitNameSet.contains(title),
                  let completionDate = reminder.completionDate else { continue }

            let dayStart = cal.startOfDay(for: completionDate)
            if dayStart >= start && dayStart <= end {
                completions[title, default: []].insert(dayStart)
            }
        }

        return completions
    }

    // MARK: - Mark Complete

    func markComplete(habitName: String, date: Date) async throws {
        let calendar = try findOrCreateHabitsList()
        let reminder = EKReminder(eventStore: store)
        reminder.title = habitName
        reminder.calendar = calendar
        reminder.isCompleted = true
        reminder.completionDate = date

        try store.save(reminder, commit: true)
    }

    // MARK: - Mark Incomplete

    func markIncomplete(habitName: String, date: Date) async throws {
        let calendar = try findOrCreateHabitsList()
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)

        for reminder in reminders {
            guard reminder.isCompleted,
                  reminder.title == habitName,
                  let completionDate = reminder.completionDate,
                  cal.isDate(completionDate, inSameDayAs: targetDay) else { continue }

            try store.remove(reminder, commit: true)
            return
        }
    }

    // MARK: - Store Changed Notification

    nonisolated var storeChangedNotificationName: Notification.Name {
        .EKEventStoreChanged
    }
}
