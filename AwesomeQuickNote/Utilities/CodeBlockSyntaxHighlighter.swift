import AppKit
import Highlightr

final class CodeBlockSyntaxHighlighter {
    static let shared = CodeBlockSyntaxHighlighter()
    private let highlightr: Highlightr?

    private init() {
        highlightr = Highlightr()
        highlightr?.setTheme(to: "monokai-sublime")
    }

    /// Apply syntax colors to a code range within textStorage.
    /// Only copies .foregroundColor from Highlightr's output —
    /// our ASTHighlighter already handles font and background.
    func highlight(code: String, language: String?, in textStorage: NSTextStorage, at codeRange: NSRange) {
        guard let highlightr,
              let highlighted = highlightr.highlight(code, as: language) else { return }

        highlighted.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: highlighted.length)) { color, range, _ in
            guard let color = color as? NSColor else { return }
            let targetRange = NSRange(location: codeRange.location + range.location,
                                       length: range.length)
            guard targetRange.location + targetRange.length <= textStorage.length else { return }
            textStorage.addAttribute(.foregroundColor, value: color, range: targetRange)
        }
    }
}
