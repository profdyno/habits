import SwiftUI

struct HabitManagementView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newHabitName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Add \(viewModel.selectedFrequency.displayName) Habit") {
                    HStack {
                        TextField("Habit name", text: $newHabitName)
                            .onSubmit { addHabit() }
                        #if os(iOS)
                            .textInputAutocapitalization(.sentences)
                        #endif

                        Button("Add") { addHabit() }
                            .disabled(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !viewModel.filteredHabits.isEmpty {
                    Section("\(viewModel.selectedFrequency.displayName) Habits") {
                        ForEach(viewModel.filteredHabits) { habit in
                            Text(habit.name)
                        }
                        .onDelete { offsets in
                            viewModel.removeHabit(at: offsets)
                        }
                        .onMove { source, destination in
                            viewModel.moveHabit(from: source, to: destination)
                        }
                    }
                }
            }
            .navigationTitle("Manage Habits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
            }
        }
    }

    private func addHabit() {
        viewModel.addHabit(name: newHabitName)
        newHabitName = ""
    }
}
