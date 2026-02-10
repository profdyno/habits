import SwiftUI

struct DayHeaderView: View {
    let dayColumns: [DayColumn]
    var showWeekSeparators: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            // Spacer matching the label column
            Color.clear.frame(width: 160, height: 1)

            ForEach(Array(dayColumns.enumerated()), id: \.element.id) { index, column in
                if showWeekSeparators, index > 0, index % 7 == 0 {
                    Spacer().frame(width: 8)
                }

                VStack(spacing: 2) {
                    Text(column.label)
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary)
                    if !column.dateLabel.isEmpty {
                        Text(column.dateLabel)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(column.isToday ? .bold : .regular)
                            .foregroundStyle(column.isToday ? .primary : .secondary)
                    }
                }
                .frame(width: 44)
                .padding(.vertical, 4)
                .background {
                    if column.isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.12))
                    }
                }
            }
        }
    }
}
