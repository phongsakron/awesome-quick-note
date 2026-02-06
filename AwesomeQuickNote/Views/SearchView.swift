import SwiftUI

struct SearchView: View {
    let searchManager: SearchManager
    let notes: [Note]
    var onSelectNote: (Note) -> Void
    var onDismiss: () -> Void

    @State private var queryText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().background(Monokai.border)
            resultsList
        }
        .onAppear {
            searchManager.search(in: notes)
            selectedIndex = 0
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            searchManager.clear()
        }
        .onChange(of: searchManager.results) {
            selectedIndex = 0
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
                    if !searchManager.results.isEmpty {
                        let note = searchManager.results[selectedIndex]
                        selectNote(note)
                    }
                }
                .onKeyPress(.downArrow) {
                    if !searchManager.results.isEmpty {
                        selectedIndex = min(selectedIndex + 1, searchManager.results.count - 1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if !searchManager.results.isEmpty {
                        selectedIndex = max(selectedIndex - 1, 0)
                    }
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
                    ForEach(Array(searchManager.results.enumerated()), id: \.element.id) { index, note in
                        Button(action: { selectNote(note) }) {
                            HStack {
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
                        .background(index == selectedIndex ? Monokai.tabActiveBackground : Color.clear)
                        .clipShape(.rect(cornerRadius: 4))
                        .id(index)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedIndex) {
                proxy.scrollTo(selectedIndex, anchor: .center)
            }
        }
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
