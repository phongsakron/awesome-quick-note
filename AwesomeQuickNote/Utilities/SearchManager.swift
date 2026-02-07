import Fuse
import Foundation
import Observation

@Observable
@MainActor
final class SearchManager {
    var query: String = ""
    var results: [Note] = []

    private let fuse = Fuse(threshold: 0.4)
    private let pinManager: PinManager
    private let vaultURL: () -> URL?

    init(pinManager: PinManager, vaultURL: @escaping () -> URL?) {
        self.pinManager = pinManager
        self.vaultURL = vaultURL
    }

    func search(in notes: [Note]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = pinManager.sortNotes(notes, vaultURL: vaultURL())
            return
        }

        let scored: [(Note, Double)] = notes.compactMap { note in
            let titleResult = fuse.search(trimmed, in: note.title)
            let contentResult = fuse.search(trimmed, in: note.content)

            let titleScore = titleResult?.score ?? 1.0
            let contentScore = contentResult?.score ?? 1.0
            let bestScore = min(titleScore, contentScore)

            if bestScore < 1.0 {
                return (note, bestScore)
            }
            return nil
        }

        let sorted = scored.sorted { $0.1 == $1.1 ? $0.0.modifiedAt > $1.0.modifiedAt : $0.1 < $1.1 }.map(\.0)
        let url = vaultURL()
        let pinned = sorted.filter { pinManager.isPinned($0, vaultURL: url) }
        let unpinned = sorted.filter { !pinManager.isPinned($0, vaultURL: url) }
        results = pinned + unpinned
    }

    func clear() {
        query = ""
        results = []
    }
}
