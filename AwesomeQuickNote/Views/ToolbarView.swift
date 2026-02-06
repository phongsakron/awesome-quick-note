import SwiftUI

struct ToolbarView: View {
    var isEditMode: Bool
    var onNewNote: () -> Void
    var onSearch: () -> Void
    var onSettings: () -> Void
    var onToggleMode: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onNewNote) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Note")

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Search Notes")

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button(action: onToggleMode) {
                Image(systemName: isEditMode ? "eye" : "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isEditMode ? "Preview" : "Edit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Monokai.toolbarBackground.opacity(0.8))
    }
}
