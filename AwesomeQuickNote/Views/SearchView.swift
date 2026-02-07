import SwiftUI

struct SearchView: View {
    let searchManager: SearchManager
    let notes: [Note]
    let panelController: FloatingPanelController
    let pinManager: PinManager
    let vaultURL: URL?
    var onSelectNote: (Note) -> Void
    var onDismiss: () -> Void

    @State private var queryText: String = ""
    @State private var selectedNote: Note?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().background(Monokai.border)
            resultsList
        }
        .onAppear {
            searchManager.search(in: notes)
            selectedNote = searchManager.results.first
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchManager.clear()
        }
        .onChange(of: searchManager.results) {
            if let current = selectedNote,
               searchManager.results.contains(where: { $0.id == current.id }) {
                // keep current selection
            } else {
                selectedNote = searchManager.results.first
            }
        }
        .onChange(of: panelController.togglePinTrigger) {
            guard let note = selectedNote else { return }
            pinManager.togglePin(note, vaultURL: vaultURL)
            searchManager.search(in: notes)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Monokai.comment)
                .font(.system(size: 14))

            TextField("Search notes...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Monokai.foreground)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    if let note = selectedNote {
                        selectNote(note)
                    }
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    onDismiss()
                    return .handled
                }
                .onChange(of: queryText) {
                    searchManager.query = queryText
                    searchManager.search(in: notes)
                }

            if !queryText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Monokai.comment)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Text("Esc")
                    .font(.system(size: 11))
                    .foregroundStyle(Monokai.comment)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Monokai.tabBackground)
                    .clipShape(.rect(cornerRadius: 3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(searchManager.results) { note in
                        Button(action: { selectNote(note) }) {
                            HStack(spacing: 6) {
                                if pinManager.isPinned(note, vaultURL: vaultURL) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Monokai.keyword)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Monokai.foreground)
                                        .lineLimit(1)

                                    Text(note.content.prefix(80).replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Monokai.comment)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Monokai.comment)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(selectedNote?.id == note.id ? Monokai.tabActiveBackground : Color.clear)
                        .clipShape(.rect(cornerRadius: 4))
                        .id(note.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedNote) {
                if let id = selectedNote?.id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func moveSelection(by offset: Int) {
        let results = searchManager.results
        guard !results.isEmpty else { return }

        let currentIndex = results.firstIndex(where: { $0.id == selectedNote?.id }) ?? 0
        let newIndex = max(0, min(currentIndex + offset, results.count - 1))
        selectedNote = results[newIndex]
    }

    private func selectNote(_ note: Note) {
        onSelectNote(note)
        onDismiss()
    }

    private func clearSearch() {
        queryText = ""
        searchManager.query = ""
        searchManager.search(in: notes)
    }
}
