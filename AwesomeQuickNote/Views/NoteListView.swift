import SwiftUI

struct NoteListView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    var onDelete: ((Note) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(notes) { note in
                    noteTab(note)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .frame(height: 36)
        .background(Monokai.toolbarBackground)
    }

    private func noteTab(_ note: Note) -> some View {
        Button(action: { selectNote(note) }) {
            Text(note.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isSelected(note) ? Monokai.foreground : Monokai.comment)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected(note) ? Monokai.tabActiveBackground : Monokai.tabBackground)
                .clipShape(.rect(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete?(note)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([note.fileURL])
            }
        }
    }

    private func isSelected(_ note: Note) -> Bool {
        selectedNote?.id == note.id
    }

    private func selectNote(_ note: Note) {
        selectedNote = note
    }
}
