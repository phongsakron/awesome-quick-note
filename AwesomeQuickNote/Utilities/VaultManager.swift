import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class VaultManager {
    var notes: [Note] = []
    var vaultURL: URL?
    private var fileSystemSource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1

    private static let bookmarkKey = "vaultBookmarkData"

    var isVaultConfigured: Bool {
        vaultURL != nil
    }

    init() {
        restoreVault()
    }

    deinit {
        // fileSystemSource is cleaned up when this object is deallocated
        // Can't access MainActor-isolated properties from deinit
    }

    // MARK: - Vault Selection

    func selectVault() {
        let panel = NSOpenPanel()
        panel.title = "Select Vault Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        setVault(url: url)
    }

    func createVault() {
        let panel = NSSavePanel()
        panel.title = "Create Vault Folder"
        panel.prompt = "Create"
        panel.nameFieldStringValue = "QuickNotes"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            setVault(url: url)
        } catch {
            print("Failed to create vault folder: \(error)")
        }
    }

    private func setVault(url: URL) {
        vaultURL = url
        saveBookmark(for: url)
        loadNotes()
        startFileWatching()
    }

    // MARK: - Security-Scoped Bookmarks

    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkKey)
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    private func restoreVault() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                saveBookmark(for: url)
            }

            vaultURL = url
            loadNotes()
            startFileWatching()
        } catch {
            print("Failed to restore vault bookmark: \(error)")
        }
    }

    // MARK: - Note CRUD

    func loadNotes() {
        guard let vaultURL else { return }

        let fm = FileManager.default
        do {
            let fileURLs = try fm.contentsOfDirectory(
                at: vaultURL,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let mdFiles = fileURLs.filter { $0.pathExtension.lowercased() == "md" }

            var loadedNotes: [Note] = []
            for fileURL in mdFiles {
                if let note = loadNote(from: fileURL) {
                    loadedNotes.append(note)
                }
            }

            loadedNotes.sort { $0.modifiedAt > $1.modifiedAt }

            // Preserve existing IDs for files that haven't changed
            var updatedNotes: [Note] = []
            for var note in loadedNotes {
                if let existing = notes.first(where: { $0.fileURL == note.fileURL }) {
                    note = Note(
                        id: existing.id,
                        fileURL: note.fileURL,
                        content: note.content,
                        createdAt: note.createdAt,
                        modifiedAt: note.modifiedAt
                    )
                }
                updatedNotes.append(note)
            }

            notes = updatedNotes
        } catch {
            print("Failed to load notes: \(error)")
        }
    }

    private func loadNote(from fileURL: URL) -> Note? {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let createdAt = resourceValues.creationDate ?? Date()
            let modifiedAt = resourceValues.contentModificationDate ?? Date()

            return Note(
                fileURL: fileURL,
                content: content,
                createdAt: createdAt,
                modifiedAt: modifiedAt
            )
        } catch {
            print("Failed to load note at \(fileURL): \(error)")
            return nil
        }
    }

    func saveNote(_ note: Note) {
        do {
            try note.content.write(to: note.fileURL, atomically: true, encoding: .utf8)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].content = note.content
                notes[index].modifiedAt = Date()
            }
        } catch {
            print("Failed to save note: \(error)")
        }
    }

    func createNote() -> Note? {
        guard let vaultURL else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "\(formatter.string(from: Date())).md"
        let fileURL = vaultURL.appendingPathComponent(filename)

        let defaultContent = "# New Note\n\n"

        do {
            try defaultContent.write(to: fileURL, atomically: true, encoding: .utf8)
            let note = Note(
                fileURL: fileURL,
                content: defaultContent,
                createdAt: Date(),
                modifiedAt: Date()
            )
            notes.insert(note, at: 0)
            return note
        } catch {
            print("Failed to create note: \(error)")
            return nil
        }
    }

    func deleteNote(_ note: Note) {
        do {
            try FileManager.default.trashItem(at: note.fileURL, resultingItemURL: nil)
            notes.removeAll { $0.id == note.id }
        } catch {
            print("Failed to delete note: \(error)")
        }
    }

    func renameNote(_ note: Note, to newName: String) {
        guard let vaultURL else { return }

        let sanitized = newName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else { return }

        let newURL = vaultURL.appendingPathComponent("\(sanitized).md")
        guard newURL != note.fileURL else { return }
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return }

        do {
            try FileManager.default.moveItem(at: note.fileURL, to: newURL)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].fileURL = newURL
            }
        } catch {
            print("Failed to rename note: \(error)")
        }
    }

    // MARK: - File Watching

    private func startFileWatching() {
        stopFileWatching()
        guard let vaultURL else { return }

        directoryFileDescriptor = open(vaultURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.loadNotes()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.directoryFileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.directoryFileDescriptor = -1
        }

        source.resume()
        fileSystemSource = source
    }

    private func stopFileWatching() {
        fileSystemSource?.cancel()
        fileSystemSource = nil
    }

    // MARK: - Attachments Directory

    var attachmentsURL: URL? {
        guard let vaultURL else { return nil }
        let url = vaultURL.appendingPathComponent("attachments")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
