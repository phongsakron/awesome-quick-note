import Foundation
import Markdown

struct SourceRangeConverter {
    /// UTF-16 offset where each line starts (0-indexed array, lines are 0-indexed here)
    private let lineStartOffsets: [Int]
    /// The original lines for UTF-8→UTF-16 column conversion
    private let lines: [String]

    init(string: String) {
        let splitLines = string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        self.lines = splitLines

        var offsets: [Int] = []
        var currentOffset = 0
        for line in splitLines {
            offsets.append(currentOffset)
            currentOffset += (line as NSString).length + 1 // +1 for newline
        }
        self.lineStartOffsets = offsets
    }

    /// Convert a swift-markdown SourceRange to NSRange.
    /// SourceLocation uses 1-based line and 1-based UTF-8 byte column.
    func nsRange(from sourceRange: SourceRange) -> NSRange? {
        guard let start = utf16Offset(for: sourceRange.lowerBound),
              let end = utf16Offset(for: sourceRange.upperBound) else {
            return nil
        }
        let length = end - start
        guard length >= 0 else { return nil }
        return NSRange(location: start, length: length)
    }

    /// Convenience: get NSRange from a Markup node's range
    func nsRange(for node: any Markup) -> NSRange? {
        guard let range = node.range else { return nil }
        return nsRange(from: range)
    }

    /// Convert a SourceLocation to a UTF-16 character offset
    private func utf16Offset(for location: SourceLocation) -> Int? {
        let lineIndex = location.line - 1 // 1-based → 0-based
        guard lineIndex >= 0, lineIndex < lineStartOffsets.count else { return nil }

        let lineStart = lineStartOffsets[lineIndex]
        let line = lines[lineIndex]

        // Column is 1-based UTF-8 byte offset
        let utf8Column = location.column - 1 // 0-based byte offset within the line

        // Convert UTF-8 byte offset to UTF-16 offset
        let lineData = line.utf8
        let utf8Prefix = lineData.prefix(utf8Column)
        // Reconstruct the prefix string from UTF-8 bytes to get its UTF-16 length
        if let prefixString = String(utf8Prefix) {
            return lineStart + (prefixString as NSString).length
        }

        // Fallback: treat column as character offset
        return lineStart + utf8Column
    }
}
