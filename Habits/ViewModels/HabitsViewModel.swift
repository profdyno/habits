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

    enum PermissionStatus {
        case unknown, authorized, denied
    }

    // MARK: - Private

    private let eventKitService = EventKitService()
    private var storeChangedCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        habits = HabitStore.loadHabits()
        dayColumns = DateHelpers.computeDayColumns()
        listenForStoreChanges()
    }

    // MARK: - Permission

    func checkAndRequestPermission() async {
        let current = await eventKitService.currentAuthorizationStatus()
        switch current {
        case .authorized:
            permissionStatus = .authorized
            await loadCompletions()
        case .denied:
            permissionStatus = .denied
        case .unknown:
            let result = await eventKitService.requestAccess()
            switch result {
            case .authorized:
                permissionStatus = .authorized
                await loadCompletions()
            case .denied:
                permissionStatus = .denied
            case .unknown:
                permissionStatus = .unknown
            }
        }
    }

    // MARK: - Load Completions

    func loadCompletions() async {
        guard !habits.isEmpty, !dayColumns.isEmpty else {
            completions = [:]
            return
        }

        let names = habits.map(\.name)
        guard let startDate = dayColumns.first?.id,
              let endDate = dayColumns.last?.id else { return }

        do {
            let fetched = try await eventKitService.fetchCompletions(
                habitNames: names,
                startDate: startDate,
                endDate: endDate
            )
            completions = fetched
        } catch {
            // Silently fail — user sees stale data
        }
    }

    // MARK: - Toggle Completion (Optimistic)

    func toggleCompletion(habitName: String, date: Date) {
        let day = DateHelpers.startOfDay(date)
        let wasCompleted = completions[habitName]?.contains(day) == true

        // Optimistic update
        if wasCompleted {
            completions[habitName]?.remove(day)
        } else {
            completions[habitName, default: []].insert(day)
        }

        Task {
            do {
                if wasCompleted {
                    try await eventKitService.markIncomplete(habitName: habitName, date: day)
                } else {
                    try await eventKitService.markComplete(habitName: habitName, date: day)
                }
            } catch {
                // Revert on failure
                if wasCompleted {
                    completions[habitName, default: []].insert(day)
                } else {
                    completions[habitName]?.remove(day)
                }
            }
        }
    }

    // MARK: - Habit Management

    func addHabit(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !habits.contains(where: { $0.name == trimmed }) else { return }

        let habit = Habit(name: trimmed)
        habits.append(habit)
        HabitStore.saveHabits(habits)

        Task {
            await loadCompletions()
        }
    }

    func removeHabit(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
        HabitStore.saveHabits(habits)
    }

    func moveHabit(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        HabitStore.saveHabits(habits)
    }

    // MARK: - Summary

    func completionCountLastSevenDays(for habitName: String) -> Int {
        let days = Set(DateHelpers.lastSevenDays())
        guard let habitCompletions = completions[habitName] else { return 0 }
        return habitCompletions.intersection(days).count
    }

    // MARK: - Refresh Day Columns (midnight rollover)

    func refreshDayColumns() {
        dayColumns = DateHelpers.computeDayColumns()
    }

    // MARK: - Store Change Listener

    private func listenForStoreChanges() {
        storeChangedCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadCompletions()
                }
            }
    }
}
