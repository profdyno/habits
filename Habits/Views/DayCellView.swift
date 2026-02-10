import SwiftUI

struct DayCellView: View {
    let isCompleted: Bool
    let isFuture: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCompleted ? Color.green.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isCompleted ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
                    .frame(width: 36, height: 36)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.3 : 1.0)
    }
}
