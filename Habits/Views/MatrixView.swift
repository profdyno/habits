import SwiftUI

struct MatrixView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @State private var showingManagement = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap + to add your first habit.")
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            DayHeaderView(dayColumns: viewModel.dayColumns)
                                .padding(.bottom, 8)

                            Divider()

                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.habits) { habit in
                                    HabitRowView(
                                        habit: habit,
                                        dayColumns: viewModel.dayColumns,
                                        completions: viewModel.completions[habit.name] ?? [],
                                        completionCount: viewModel.completionCountLastSevenDays(for: habit.name),
                                        onToggle: { date in
                                            viewModel.toggleCompletion(habitName: habit.name, date: date)
                                        }
                                    )
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Habits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingManagement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingManagement) {
                HabitManagementView()
            }
        }
    }
}
