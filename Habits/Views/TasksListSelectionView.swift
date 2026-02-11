import SwiftUI

struct TasksListSelectionView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let lists = viewModel.availableLists
        return NavigationStack {
            List {
                ForEach(lists, id: \.id) { (list: ReminderListInfo) in
                    Button {
                        viewModel.toggleListSelection(list.id)
                    } label: {
                        HStack {
                            Text(list.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.selectedListIds.contains(list.id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminder Lists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
