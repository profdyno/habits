import SwiftUI
import Combine

@MainActor
final class HabitsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var habits: [Habit] = []
    @Published var completions: [String: Set<Date>] = [:]
    @Published var dayColumns: [DayColumn] = []
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var isLoading = false
    @Published var selectedFrequency: HabitFrequency = .daily

    // Comment flow state
    @Published var pendingCompletion: (habitName: String, date: Date)?
    @Published var commentText: String = ""

    enum PermissionStatus {
        case unknown, authorized, denied
    }

    // MARK: - Computed

    var filteredHabits: [Habit] {
        habits.filter { $0.frequency == selectedFrequency }
    }

    // MARK: - Private

    private let eventKitService = EventKitService()
    private var storeChangedCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        dayColumns = computeColumnsForFrequency(.daily)
        listenForStoreChanges()
    }

    // MARK: - Permission

    func checkAndRequestPermission() async {
        let current = await eventKitService.currentAuthorizationStatus()
        switch current {
        case .authorized:
            permissionStatus = .authorized
            await loadHabitsFromReminders()
            await loadCompletions()
        case .denied:
            permissionStatus = .denied
        case .unknown:
            let result = await eventKitService.requestAccess()
            switch result {
            case .authorized:
                permissionStatus = .authorized
                await loadHabitsFromReminders()
                await loadCompletions()
            case .denied:
                permissionStatus = .denied
            case .unknown:
                permissionStatus = .unknown
            }
        }
    }

    // MARK: - Frequency Selection

    func selectFrequency(_ frequency: HabitFrequency) {
        selectedFrequency = frequency
        dayColumns = computeColumnsForFrequency(frequency)
        Task {
            await loadHabitsFromReminders()
            await loadCompletions()
        }
    }

    private func computeColumnsForFrequency(_ frequency: HabitFrequency) -> [DayColumn] {
        switch frequency {
        case .daily:
            let weeks = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
            return DateHelpers.computeDayColumns(weeks: weeks)
        case .weekly:
            return DateHelpers.computeWeekColumns(count: 14)
        case .monthly:
            return DateHelpers.computeMonthColumns(count: 13)
        }
    }

    // MARK: - Load Habits from Reminders

    func loadHabitsFromReminders() async {
        do {
            let remoteNames = try await eventKitService.fetchHabitNames(frequency: selectedFrequency)
            let storedOrder = HabitStore.loadOrder(for: selectedFrequency)

            // Merge: use stored order for known names, append new ones at end
            var ordered: [String] = []
            let remoteSet = Set(remoteNames)
            for name in storedOrder where remoteSet.contains(name) {
                ordered.append(name)
            }
            for name in remoteNames where !ordered.contains(name) {
                ordered.append(name)
            }

            // Remove habits of this frequency and rebuild
            habits.removeAll { $0.frequency == selectedFrequency }
            let newHabits = ordered.map { Habit(name: $0, frequency: selectedFrequency) }
            habits.append(contentsOf: newHabits)

            HabitStore.saveOrder(ordered, for: selectedFrequency)
        } catch {
            // Fall back to stored order
            let storedOrder = HabitStore.loadOrder(for: selectedFrequency)
            habits.removeAll { $0.frequency == selectedFrequency }
            let newHabits = storedOrder.map { Habit(name: $0, frequency: selectedFrequency) }
            habits.append(contentsOf: newHabits)
        }
    }

    // MARK: - Load Completions

    func loadCompletions() async {
        let filtered = filteredHabits
        guard !filtered.isEmpty, !dayColumns.isEmpty else {
            completions = [:]
            return
        }

        let names = filtered.map(\.name)
        guard let startDate = dayColumns.first?.id,
              let endDate = dayColumns.last?.id else { return }

        do {
            let fetched = try await eventKitService.fetchCompletions(
                habitNames: names,
                startDate: startDate,
                endDate: endDate,
                frequency: selectedFrequency
            )
            completions = fetched
        } catch {
            // Silently fail — user sees stale data
        }
    }

    // MARK: - Toggle Completion (with comment prompt)

    func toggleCompletion(habitName: String, date: Date) {
        let period = DateHelpers.periodStart(for: date, frequency: selectedFrequency)
        let wasCompleted = completions[habitName]?.contains(period) == true

        if wasCompleted {
            // Uncomplete immediately, no prompt
            completions[habitName]?.remove(period)
            Task {
                do {
                    try await eventKitService.markIncomplete(habitName: habitName, date: period, frequency: selectedFrequency)
                } catch {
                    completions[habitName, default: []].insert(period)
                }
            }
        } else {
            // Show comment prompt
            pendingCompletion = (habitName: habitName, date: period)
            commentText = ""
        }
    }

    func confirmCompletion() {
        guard let pending = pendingCompletion else { return }
        let comment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Optimistic update
        completions[pending.habitName, default: []].insert(pending.date)

        let capturedComment = comment.isEmpty ? nil : comment
        Task {
            do {
                try await eventKitService.markComplete(
                    habitName: pending.habitName,
                    date: pending.date,
                    comment: capturedComment,
                    frequency: selectedFrequency
                )
            } catch {
                completions[pending.habitName]?.remove(pending.date)
            }
        }

        pendingCompletion = nil
        commentText = ""
    }

    func skipComment() {
        guard let pending = pendingCompletion else { return }

        // Optimistic update
        completions[pending.habitName, default: []].insert(pending.date)

        Task {
            do {
                try await eventKitService.markComplete(
                    habitName: pending.habitName,
                    date: pending.date,
                    comment: nil,
                    frequency: selectedFrequency
                )
            } catch {
                completions[pending.habitName]?.remove(pending.date)
            }
        }

        pendingCompletion = nil
        commentText = ""
    }

    func cancelCompletion() {
        pendingCompletion = nil
        commentText = ""
    }

    // MARK: - Habit Management

    func addHabit(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !filteredHabits.contains(where: { $0.name == trimmed }) else { return }

        let habit = Habit(name: trimmed, frequency: selectedFrequency)
        habits.append(habit)
        HabitStore.saveOrder(filteredHabits.map(\.name), for: selectedFrequency)

        Task {
            do {
                try await eventKitService.addHabitReminder(name: trimmed, frequency: selectedFrequency)
            } catch {
                // Reminder creation failed but habit is still in local list
            }
            await loadCompletions()
        }
    }

    func removeHabit(at offsets: IndexSet) {
        let filtered = filteredHabits
        let namesToRemove = offsets.map { filtered[$0].name }

        habits.removeAll { habit in
            habit.frequency == selectedFrequency && namesToRemove.contains(habit.name)
        }
        HabitStore.saveOrder(filteredHabits.map(\.name), for: selectedFrequency)

        Task {
            for name in namesToRemove {
                try? await eventKitService.removeHabitReminder(name: name, frequency: selectedFrequency)
            }
        }
    }

    func moveHabit(from source: IndexSet, to destination: Int) {
        var filtered = filteredHabits
        filtered.move(fromOffsets: source, toOffset: destination)

        // Rebuild habits array: remove all of this frequency, re-insert in new order
        habits.removeAll { $0.frequency == selectedFrequency }
        habits.append(contentsOf: filtered)
        HabitStore.saveOrder(filtered.map(\.name), for: selectedFrequency)
    }

    // MARK: - Summary

    func completionCountForSummary(for habitName: String) -> Int {
        let periods = Set(DateHelpers.lastPeriods(frequency: selectedFrequency, count: selectedFrequency.summaryPeriodCount))
        guard let habitCompletions = completions[habitName] else { return 0 }
        return habitCompletions.intersection(periods).count
    }

    // MARK: - Refresh Day Columns (midnight rollover)

    func refreshDayColumns() {
        dayColumns = computeColumnsForFrequency(selectedFrequency)
    }

    // MARK: - Store Change Listener

    private func listenForStoreChanges() {
        storeChangedCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadHabitsFromReminders()
                    await self?.loadCompletions()
                }
            }
    }
}
