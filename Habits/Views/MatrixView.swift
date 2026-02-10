import SwiftUI

struct MatrixView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingManagement = false

    private var showWeekSeparators: Bool {
        viewModel.selectedFrequency == .daily
    }

    // Row height constants (must match between frozen labels and scrollable columns)
    private let headerHeight: CGFloat = 44
    private let summaryRowHeight: CGFloat = 20
    private let percentageRowHeight: CGFloat = 20
    private let separatorHeight: CGFloat = 9 // 1pt line + 4pt padding top/bottom
    private let habitRowHeight: CGFloat = 48 // 44pt cell + 4pt vertical padding
    private let headerBottomPadding: CGFloat = 4

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
                    HStack(alignment: .top, spacing: 0) {
                        // MARK: - Frozen label column
                        VStack(alignment: .leading, spacing: 0) {
                            // Header label
                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 40)
                                Text("%")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                                Text("Habit")
                                    .font(.system(.caption2))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 200, height: headerHeight)
                            .padding(.bottom, headerBottomPadding)

                            // Summary label
                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 40)
                                Text("")
                                    .frame(width: 44)
                                Text("Total")
                                    .font(.system(.caption2))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 200, height: summaryRowHeight)

                            // Percentage label (blank)
                            Color.clear
                                .frame(width: 200, height: percentageRowHeight)

                            // Separator
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: 200, height: 1)
                                .padding(.vertical, 4)

                            // Habit labels
                            ForEach(viewModel.filteredHabits) { habit in
                                let overall = viewModel.habitOverallCompletion(for: habit.name)
                                let pct = viewModel.habitOverallPercentage(for: habit.name)
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("\(overall.completed)/\(overall.total)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 40, alignment: .trailing)
                                        Text(String(format: "%.1f%%", pct))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, alignment: .trailing)
                                        Text(habit.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .padding(.leading, 4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(width: 200, height: habitRowHeight)
                                    Divider()
                                }
                            }
                        }

                        // MARK: - Scrollable columns
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                DayHeaderView(
                                    dayColumns: viewModel.dayColumns,
                                    showWeekSeparators: showWeekSeparators
                                )
                                .frame(height: headerHeight)
                                .padding(.bottom, headerBottomPadding)

                                SummaryRowView(
                                    dayColumns: viewModel.dayColumns,
                                    columnSummaries: viewModel.columnSummaries,
                                    showWeekSeparators: showWeekSeparators
                                )
                                .frame(height: summaryRowHeight)

                                PercentageRowView(
                                    dayColumns: viewModel.dayColumns,
                                    columnPercentages: viewModel.columnPercentages,
                                    showWeekSeparators: showWeekSeparators
                                )
                                .frame(height: percentageRowHeight)

                                Rectangle()
                                    .fill(Color.primary)
                                    .frame(height: 1)
                                    .padding(.vertical, 4)

                                ForEach(viewModel.filteredHabits) { habit in
                                    VStack(spacing: 0) {
                                        HabitRowView(
                                            dayColumns: viewModel.dayColumns,
                                            completions: viewModel.completions[habit.name] ?? [],
                                            showWeekSeparators: showWeekSeparators,
                                            onToggle: { date in
                                                viewModel.toggleCompletion(habitName: habit.name, date: date)
                                            }
                                        )
                                        .frame(height: habitRowHeight)
                                        Divider()
                                    }
                                }
                            }
                            .padding(.trailing)
                        }
                    }
                    .padding(.leading)
                    .padding(.top)
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.refreshDayColumns()
                    Task { await viewModel.refreshFromReminders() }
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
