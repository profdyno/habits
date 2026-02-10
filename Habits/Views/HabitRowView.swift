import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let dayColumns: [DayColumn]
    let completions: Set<Date>
    let completionCount: Int
    let onToggle: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Summary + name label (160pt total)
            HStack(spacing: 6) {
                Text("\(completionCount)/7")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                Text(habit.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 160, alignment: .leading)

            // Day cells with gaps between each week
            ForEach(Array(dayColumns.enumerated()), id: \.element.id) { index, column in
                if index > 0, index % 7 == 0 {
                    Spacer().frame(width: 8)
                }

                DayCellView(
                    isCompleted: completions.contains(column.id),
                    isFuture: column.isFuture,
                    onToggle: { onToggle(column.id) }
                )
            }
        }
        .padding(.vertical, 2)
    }
}
