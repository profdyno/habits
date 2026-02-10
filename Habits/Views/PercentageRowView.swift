import SwiftUI

struct PercentageRowView: View {
    let dayColumns: [DayColumn]
    let columnPercentages: [Double]
    var showWeekSeparators: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayColumns.enumerated()), id: \.element.id) { index, _ in
                if showWeekSeparators, index > 0, index % 7 == 0 {
                    Spacer().frame(width: 8)
                }

                if index < columnPercentages.count {
                    if dayColumns[index].isFuture {
                        Color.clear.frame(width: 44, height: 1)
                    } else {
                        Text(String(format: "%.0f%%", columnPercentages[index]))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44)
                    }
                }
            }
        }
    }
}
