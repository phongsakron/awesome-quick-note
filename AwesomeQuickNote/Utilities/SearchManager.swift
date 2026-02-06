import Fuse
import Foundation
import Observation

@Observable
@MainActor
final class SearchManager {
    var query: String = ""
    var results: [Note] = []

    private let fuse = Fuse(threshold: 0.4)

    func search(in notes: [Note]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = notes.sorted { $0.modifiedAt > $1.modifiedAt }
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

        results = scored.sorted { $0.1 == $1.1 ? $0.0.modifiedAt > $1.0.modifiedAt : $0.1 < $1.1 }.map(\.0)
    }

    func clear() {
        query = ""
        results = []
    }
}
