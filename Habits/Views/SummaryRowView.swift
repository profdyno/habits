import SwiftUI

struct SummaryRowView: View {
    let dayColumns: [DayColumn]
    let columnSummaries: [(completed: Int, total: Int)]
    var showWeekSeparators: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayColumns.enumerated()), id: \.element.id) { index, _ in
                if showWeekSeparators, index > 0, index % 7 == 0 {
                    Spacer().frame(width: 8)
                }

                if index < columnSummaries.count {
                    if dayColumns[index].isFuture {
                        Color.clear.frame(width: 44, height: 1)
                    } else {
                        let summary = columnSummaries[index]
                        Text("\(summary.completed)/\(summary.total)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44)
                    }
                }
            }
        }
    }
}
