import EventKit
import Foundation

actor EventKitService {
    private let store = EKEventStore()
    private var calendars: [HabitFrequency: EKCalendar] = [:]

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

    private func findOrCreateHabitsList(for frequency: HabitFrequency) throws -> EKCalendar {
        if let cached = calendars[frequency] {
            if store.calendar(withIdentifier: cached.calendarIdentifier) != nil {
                return cached
            }
        }

        let allCalendars = store.calendars(for: .reminder)
        if let existing = allCalendars.first(where: { $0.title == frequency.listName }) {
            calendars[frequency] = existing
            return existing
        }

        let newCalendar = EKCalendar(for: .reminder, eventStore: store)
        newCalendar.title = frequency.listName

        if let defaultSource = store.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let firstSource = store.sources.first {
            newCalendar.source = firstSource
        }

        try store.saveCalendar(newCalendar, commit: true)
        calendars[frequency] = newCalendar
        return newCalendar
    }

    // MARK: - Discover Habits from Reminders

    /// Returns unique titles of incomplete reminders in the frequency's list.
    func fetchHabitNames(frequency: HabitFrequency) async throws -> [String] {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        var seen = Set<String>()
        var names: [String] = []
        for reminder in reminders {
            guard !reminder.isCompleted,
                  let title = reminder.title,
                  !title.isEmpty,
                  !seen.contains(title) else { continue }
            seen.insert(title)
            names.append(title)
        }

        return names
    }

    // MARK: - Add / Remove Habit Reminders

    /// Creates an incomplete reminder as the habit definition.
    func addHabitReminder(name: String, frequency: HabitFrequency) async throws {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let reminder = EKReminder(eventStore: store)
        reminder.title = name
        reminder.calendar = calendar
        reminder.isCompleted = false
        try store.save(reminder, commit: true)
    }

    /// Deletes the incomplete reminder for this habit.
    func removeHabitReminder(name: String, frequency: HabitFrequency) async throws {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        for reminder in reminders {
            guard !reminder.isCompleted,
                  reminder.title == name else { continue }
            try store.remove(reminder, commit: true)
            return
        }
    }

    // MARK: - Fetch Completions

    /// Returns a dictionary mapping habit names to sets of period-start dates.
    func fetchCompletions(
        habitNames: [String],
        startDate: Date,
        endDate: Date,
        frequency: HabitFrequency
    ) async throws -> [String: Set<Date>] {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let start = DateHelpers.periodStart(for: startDate, frequency: frequency)
        let end = DateHelpers.periodStart(for: endDate, frequency: frequency)
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

            let periodDate = DateHelpers.periodStart(for: completionDate, frequency: frequency)
            if periodDate >= start && periodDate <= end {
                completions[title, default: []].insert(periodDate)
            }
        }

        return completions
    }

    // MARK: - Mark Complete

    func markComplete(habitName: String, date: Date, comment: String?, frequency: HabitFrequency) async throws {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let reminder = EKReminder(eventStore: store)
        reminder.title = habitName
        reminder.calendar = calendar
        reminder.isCompleted = true
        reminder.completionDate = date

        // Build notes with optional comment and timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm a"
        let timestamp = "(Habits \(formatter.string(from: Date())))"
        if let comment = comment, !comment.isEmpty {
            reminder.notes = "\(comment)\n\(timestamp)"
        } else {
            reminder.notes = timestamp
        }

        // Set due date to column date + current time for proper sorting
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: date)
        let now = Date()
        components.hour = cal.component(.hour, from: now)
        components.minute = cal.component(.minute, from: now)
        reminder.dueDateComponents = components

        try store.save(reminder, commit: true)
    }

    // MARK: - Mark Incomplete

    func markIncomplete(habitName: String, date: Date, frequency: HabitFrequency) async throws {
        let calendar = try findOrCreateHabitsList(for: frequency)
        let predicate = store.predicateForReminders(in: [calendar])

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let targetPeriod = DateHelpers.periodStart(for: date, frequency: frequency)

        for reminder in reminders {
            guard reminder.isCompleted,
                  reminder.title == habitName,
                  let completionDate = reminder.completionDate else { continue }

            let reminderPeriod = DateHelpers.periodStart(for: completionDate, frequency: frequency)
            if reminderPeriod == targetPeriod {
                try store.remove(reminder, commit: true)
                return
            }
        }
    }

    // MARK: - Store Changed Notification

    nonisolated var storeChangedNotificationName: Notification.Name {
        .EKEventStoreChanged
    }
}
