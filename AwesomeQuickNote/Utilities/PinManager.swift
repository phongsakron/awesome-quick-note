import Foundation
import Observation

@Observable
@MainActor
final class PinManager {
    private static let defaultsKey = "pinnedNotePaths"

    private var pinnedPaths: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(pinnedPaths), forKey: Self.defaultsKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        self.pinnedPaths = Set(saved)
    }

    func isPinned(_ note: Note, vaultURL: URL?) -> Bool {
        guard let relativePath = Self.relativePath(for: note, vaultURL: vaultURL) else { return false }
        return pinnedPaths.contains(relativePath)
    }

    func togglePin(_ note: Note, vaultURL: URL?) {
        guard let relativePath = Self.relativePath(for: note, vaultURL: vaultURL) else { return }
        if pinnedPaths.contains(relativePath) {
            pinnedPaths.remove(relativePath)
        } else {
            pinnedPaths.insert(relativePath)
        }
    }

    func sortNotes(_ notes: [Note], vaultURL: URL?) -> [Note] {
        let pinned = notes.filter { isPinned($0, vaultURL: vaultURL) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        let unpinned = notes.filter { !isPinned($0, vaultURL: vaultURL) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        return pinned + unpinned
    }

    private static func relativePath(for note: Note, vaultURL: URL?) -> String? {
        guard let vaultURL else { return nil }
        let notePath = note.fileURL.standardizedFileURL.path
        let vaultPath = vaultURL.standardizedFileURL.path.hasSuffix("/")
            ? vaultURL.standardizedFileURL.path
            : vaultURL.standardizedFileURL.path + "/"
        guard notePath.hasPrefix(vaultPath) else { return nil }
        return String(notePath.dropFirst(vaultPath.count))
    }
}
