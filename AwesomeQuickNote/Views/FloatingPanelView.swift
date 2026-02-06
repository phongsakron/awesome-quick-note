import SwiftUI

struct FloatingPanelView: View {
    let vaultManager: VaultManager
    let panelController: FloatingPanelController
    let searchManager: SearchManager
    let imageManager: ImageManager

    @State private var selectedNote: Note?
    @State private var isEditMode: Bool = true
    @State private var editingContent: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var editorFocusTrigger: Bool = false

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if vaultManager.isVaultConfigured {
                    mainContent
                } else {
                    VaultSetupView(vaultManager: vaultManager)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 300)
        .onChange(of: panelController.isVisible) {
            if panelController.isVisible {
                panelController.dismissOverlays()
                editorFocusTrigger = true
            }
        }
        .onChange(of: panelController.pendingNewNote) {
            if panelController.pendingNewNote {
                handleNewNote()
                panelController.pendingNewNote = false
            }
        }
        .onChange(of: vaultManager.notes) {
            if let selected = selectedNote,
               !vaultManager.notes.contains(where: { $0.id == selected.id }) {
                selectedNote = vaultManager.notes.first
                syncEditingContent()
            }
        }
        .onChange(of: selectedNote) {
            syncEditingContent()
        }
        .onChange(of: editingContent) {
            scheduleSave()
        }
        .onAppear {
            if selectedNote == nil, let first = vaultManager.notes.first {
                selectedNote = first
                syncEditingContent()
            }
            editorFocusTrigger = true
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ToolbarView(
            isEditMode: isEditMode,
            onNewNote: handleNewNote,
            onSearch: handleSearch,
            onSettings: handleSettings,
            onToggleMode: toggleMode
        )

        Divider().background(Monokai.border)

        if panelController.isSettingsActive {
            SettingsView(vaultManager: vaultManager, onDismiss: dismissOverlays)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if panelController.isSearchActive {
            SearchView(
                searchManager: searchManager,
                notes: vaultManager.notes,
                onSelectNote: selectNote,
                onDismiss: dismissOverlays
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedNote != nil {
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

    }

    @ViewBuilder
    private var contentArea: some View {
        if isEditMode {
            NoteEditorView(
                text: $editingContent,
                onImagePaste: { image in
                    imageManager.saveImage(image)
                },
                shouldFocus: editorFocusTrigger
            )
        } else {
            NotePreviewView(
                content: editingContent,
                vaultURL: vaultManager.vaultURL,
                onToggleCheckbox: { lineIndex in
                    toggleCheckbox(at: lineIndex)
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(Monokai.comment)
            Text("No notes yet")
                .foregroundStyle(Monokai.comment)
            Button("Create Note", action: handleNewNote)
                .buttonStyle(.borderedProminent)
                .tint(Monokai.keyword)
        }
    }

    // MARK: - Actions

    private func handleNewNote() {
        panelController.dismissOverlays()
        if let note = vaultManager.createNote() {
            selectedNote = note
            editingContent = note.content
            isEditMode = true
            editorFocusTrigger = true
        }
    }

    private func handleSearch() {
        editorFocusTrigger = false
        panelController.showSearch()
    }

    private func handleSettings() {
        editorFocusTrigger = false
        panelController.showSettings()
    }

    private func toggleMode() {
        if isEditMode {
            saveCurrentNote()
            editorFocusTrigger = false
        } else {
            editorFocusTrigger = true
        }
        isEditMode.toggle()
    }

    private func dismissOverlays() {
        panelController.dismissOverlays()
        editorFocusTrigger = true
    }

    private func selectNote(_ note: Note) {
        saveCurrentNote()
        selectedNote = note
    }

    private func deleteNote(_ note: Note) {
        let wasSelected = selectedNote?.id == note.id
        vaultManager.deleteNote(note)
        if wasSelected {
            selectedNote = vaultManager.notes.first
        }
    }

    private func syncEditingContent() {
        if let note = selectedNote,
           let latest = vaultManager.notes.first(where: { $0.id == note.id }) {
            editingContent = latest.content
        } else {
            editingContent = selectedNote?.content ?? ""
        }
    }

    private func saveCurrentNote() {
        guard var note = selectedNote else { return }
        note.content = editingContent
        vaultManager.saveNote(note)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveCurrentNote()
        }
    }

    private func toggleCheckbox(at lineIndex: Int) {
        var lines = editingContent.components(separatedBy: "\n")
        guard lineIndex < lines.count else { return }

        let line = lines[lineIndex]
        if line.contains("- [ ]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
        } else if line.contains("- [x]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [x]", with: "- [ ]")
        }

        editingContent = lines.joined(separator: "\n")
        saveCurrentNote()
    }
}
