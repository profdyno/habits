import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Frozen header row
            HStack(spacing: 1) {
                ForEach(viewModel.taskColumns) { column in
                    let summary = viewModel.taskColumnSummary(for: column)
                    VStack(spacing: 2) {
                        Text(column.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text("\(column.dayLabel) (\(summary.completed)/\(summary.total))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(column.isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                    .onTapGesture {
                        if column.isDelinquent {
                            viewModel.openDelinquentInReminders()
                        }
                    }
                }
            }

            Divider()

            // Scrollable task content
            if viewModel.selectedListIds.isEmpty {
                ContentUnavailableView(
                    "No Lists Selected",
                    systemImage: "checklist",
                    description: Text("Tap the gear icon to choose which Reminder lists to show.")
                )
            } else {
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 1) {
                        ForEach(viewModel.taskColumns) { column in
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.tasksByColumn[column.id] ?? []) { task in
                                    HStack(spacing: 6) {
                                        Button {
                                            viewModel.toggleTaskCompletion(task)
                                        } label: {
                                            Image(systemName: task.isCompleted
                                                ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                        }
                                        .buttonStyle(.plain)

                                        Text(task.title)
                                            .font(.caption)
                                            .strikethrough(task.isCompleted)
                                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                            .lineLimit(2)
                                            .onTapGesture {
                                                viewModel.openTaskInReminders(task)
                                            }
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
        }
    }
}
