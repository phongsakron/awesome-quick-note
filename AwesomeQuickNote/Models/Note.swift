import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var fileURL: URL
    var content: String
    var createdAt: Date
    var modifiedAt: Date

    var title: String {
        let firstLine = content.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        if firstLine.hasPrefix("# ") {
            return String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return fileURL.deletingPathExtension().lastPathComponent
    }

    var fileName: String {
        fileURL.lastPathComponent
    }

    init(id: UUID = UUID(), fileURL: URL, content: String, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.fileURL = fileURL
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}
