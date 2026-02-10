import SwiftUI

struct MatrixView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @State private var showingManagement = false

    private var showWeekSeparators: Bool {
        viewModel.selectedFrequency == .daily
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Frequency picker
                Picker("Frequency", selection: Binding(
                    get: { viewModel.selectedFrequency },
                    set: { viewModel.selectFrequency($0) }
                )) {
                    ForEach(HabitFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if viewModel.filteredHabits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap + to add your first \(viewModel.selectedFrequency.displayName.lowercased()) habit.")
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            DayHeaderView(
                                dayColumns: viewModel.dayColumns,
                                showWeekSeparators: showWeekSeparators
                            )
                            .padding(.bottom, 8)

                            Divider()

                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.filteredHabits) { habit in
                                    HabitRowView(
                                        habit: habit,
                                        dayColumns: viewModel.dayColumns,
                                        completions: viewModel.completions[habit.name] ?? [],
                                        completionCount: viewModel.completionCountForSummary(for: habit.name),
                                        summaryDenominator: viewModel.selectedFrequency.summaryPeriodCount,
                                        showWeekSeparators: showWeekSeparators,
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
                    .frame(maxHeight: .infinity, alignment: .top)
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
            .alert(
                "Comment",
                isPresented: Binding(
                    get: { viewModel.pendingCompletion != nil },
                    set: { if !$0 { viewModel.cancelCompletion() } }
                )
            ) {
                TextField("Optional comment...", text: $viewModel.commentText)
                Button("Save") { viewModel.confirmCompletion() }
                Button("Skip") { viewModel.skipComment() }
                Button("Cancel", role: .cancel) { viewModel.cancelCompletion() }
            } message: {
                if let pending = viewModel.pendingCompletion {
                    Text("Mark \"\(pending.habitName)\" as complete")
                }
            }
        }
    }
}
