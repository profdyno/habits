import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    private var parsed: ParsedTaskInput {
        TaskInputParser.parse(input, availableLists: viewModel.availableLists)
    }

    private var canAdd: Bool {
        !parsed.title.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Complete QSR on Friday in Work", text: $input)
                        .focused($inputFocused)
                        .onSubmit { addAndDismiss() }
                        .submitLabel(.done)
                }

                if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Preview") {
                        LabeledContent("Title") {
                            Text(parsed.title.isEmpty ? "—" : parsed.title)
                                .foregroundStyle(parsed.title.isEmpty ? .secondary : .primary)
                        }
                        LabeledContent("Due") {
                            if let date = parsed.dueDate {
                                Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            } else {
                                Text("Today")
                            }
                        }
                        LabeledContent("List") {
                            Text(parsed.listName ?? "Default")
                                .foregroundStyle(parsed.listName != nil ? .primary : .secondary)
                        }
                    }
                }

                Section("Available Lists") {
                    ForEach(viewModel.availableLists) { list in
                        Text(list.title)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addAndDismiss() }
                        .disabled(!canAdd)
                }
            }
            .onAppear { inputFocused = true }
        }
    }

    private func addAndDismiss() {
        guard canAdd else { return }
        let result = parsed

        // Resolve calendar: parsed list, or first selected list, or first available
        let calendarId: String
        if let id = result.listId {
            calendarId = id
        } else if let first = viewModel.selectedListIds.first {
            calendarId = first
        } else if let first = viewModel.availableLists.first?.id {
            calendarId = first
        } else {
            return
        }

        viewModel.addTask(
            title: result.title,
            dueDate: result.dueDate ?? Date(),
            calendarId: calendarId
        )
        dismiss()
    }
}
