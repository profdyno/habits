import SwiftUI

struct HabitRowView: View {
    let dayColumns: [DayColumn]
    let completions: Set<Date>
    var showWeekSeparators: Bool = true
    let onToggle: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayColumns.enumerated()), id: \.element.id) { index, column in
                if showWeekSeparators, index > 0, index % 7 == 0 {
                    Spacer().frame(width: 8)
                }

                DayCellView(
                    isCompleted: completions.contains(column.id),
                    isFuture: column.isFuture,
                    onToggle: { onToggle(column.id) }
                )
            }
        }
    }
}
