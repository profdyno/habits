import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left third: editable note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Work ELT Weekly Summary")
                        .font(.headline)
                    TextEditor(text: $viewModel.noteText)
                        .font(.body)
                        .onChange(of: viewModel.noteText) { _, _ in
                            viewModel.saveNote()
                        }
                }
                .padding()
                .frame(width: geometry.size.width / 3)

                Divider()

                // Right two-thirds: empty for now
                Spacer()
            }
        }
    }
}
