import AppKit

extension NSAttributedString.Key {
    static let checkboxRange = NSAttributedString.Key("checkboxRange")
}

final class MarkdownHighlighter {
    private var isHighlighting = false

    private var baseFont: NSFont
    private let baseForeground = Monokai.foregroundNS

    // Pre-built heading fonts
    private var h1Font: NSFont
    private var h2Font: NSFont
    private var h3Font: NSFont
    private var h4Font: NSFont
    private var h5Font: NSFont
    private var h6Font: NSFont

    // Pre-built style fonts
    private var boldFont: NSFont
    private var italicFont: NSFont
    private var boldItalicFont: NSFont
    private var codeFont: NSFont

    // Track current settings to detect changes
    private var currentFontFamily: String = ""
    private var currentFontSize: CGFloat = 0

    // Pre-compiled regex patterns
    private let headingH1to3Regex: NSRegularExpression
    private let headingH4to6Regex: NSRegularExpression
    private let boldItalicRegex: NSRegularExpression
    private let boldRegex: NSRegularExpression
    private let italicRegex: NSRegularExpression
    private let inlineCodeRegex: NSRegularExpression
    private let strikethroughRegex: NSRegularExpression
    private let blockquoteRegex: NSRegularExpression
    private let unorderedListRegex: NSRegularExpression
    private let orderedListRegex: NSRegularExpression
    private let checkboxRegex: NSRegularExpression
    private let linkRegex: NSRegularExpression

    init(fontSettings: FontSettings? = nil) {
        let fm = NSFontManager.shared
        let size: CGFloat = fontSettings?.fontSize ?? 14

        if let fontSettings {
            baseFont = fontSettings.editorFont()
            h1Font = fontSettings.boldFont(ofSize: size + 10)
            h2Font = fontSettings.boldFont(ofSize: size + 6)
            h3Font = fontSettings.boldFont(ofSize: size + 3)
            h4Font = fontSettings.font(ofSize: size + 1, weight: .semibold)
            h5Font = fontSettings.font(ofSize: size, weight: .medium)
            h6Font = fontSettings.font(ofSize: size - 1, weight: .medium)
            boldFont = fontSettings.boldFont(ofSize: size)
            italicFont = fontSettings.italicFont(ofSize: size)
            boldItalicFont = fontSettings.boldItalicFont(ofSize: size)
            codeFont = fontSettings.font(ofSize: size - 1)
            currentFontFamily = fontSettings.fontFamily
            currentFontSize = fontSettings.fontSize
        } else {
            baseFont = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            h1Font = fm.convert(NSFont.monospacedSystemFont(ofSize: size + 10, weight: .bold), toHaveTrait: .boldFontMask)
            h2Font = fm.convert(NSFont.monospacedSystemFont(ofSize: size + 6, weight: .bold), toHaveTrait: .boldFontMask)
            h3Font = fm.convert(NSFont.monospacedSystemFont(ofSize: size + 3, weight: .bold), toHaveTrait: .boldFontMask)
            h4Font = NSFont.monospacedSystemFont(ofSize: size + 1, weight: .semibold)
            h5Font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
            h6Font = NSFont.monospacedSystemFont(ofSize: size - 1, weight: .medium)
            boldFont = fm.convert(NSFont.monospacedSystemFont(ofSize: size, weight: .bold), toHaveTrait: .boldFontMask)
            italicFont = fm.convert(NSFont.monospacedSystemFont(ofSize: size, weight: .regular), toHaveTrait: .italicFontMask)
            boldItalicFont = fm.convert(fm.convert(NSFont.monospacedSystemFont(ofSize: size, weight: .bold), toHaveTrait: .boldFontMask), toHaveTrait: .italicFontMask)
            codeFont = NSFont.monospacedSystemFont(ofSize: size - 1, weight: .regular)
        }

        // Compile regex patterns
        headingH1to3Regex = try! NSRegularExpression(pattern: "^(#{1,3})\\s+(.+)$", options: .anchorsMatchLines)
        headingH4to6Regex = try! NSRegularExpression(pattern: "^(#{4,6})\\s+(.+)$", options: .anchorsMatchLines)
        boldItalicRegex = try! NSRegularExpression(pattern: "\\*\\*\\*(.+?)\\*\\*\\*", options: [])
        boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
        italicRegex = try! NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)", options: [])
        inlineCodeRegex = try! NSRegularExpression(pattern: "(?<!`)`(?!`)([^`]+?)(?<!`)`(?!`)", options: [])
        strikethroughRegex = try! NSRegularExpression(pattern: "~~(.+?)~~", options: [])
        blockquoteRegex = try! NSRegularExpression(pattern: "^>\\s+(.+)$", options: .anchorsMatchLines)
        unorderedListRegex = try! NSRegularExpression(pattern: "^(\\s*[-*+])\\s", options: .anchorsMatchLines)
        orderedListRegex = try! NSRegularExpression(pattern: "^(\\s*\\d+\\.)\\s", options: .anchorsMatchLines)
        checkboxRegex = try! NSRegularExpression(pattern: "^(\\s*- \\[)([ x])(\\])", options: .anchorsMatchLines)
        linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: [])
    }

    func updateFonts(from fontSettings: FontSettings) {
        guard fontSettings.fontFamily != currentFontFamily || fontSettings.fontSize != currentFontSize else { return }

        let size = fontSettings.fontSize
        baseFont = fontSettings.editorFont()
        h1Font = fontSettings.boldFont(ofSize: size + 10)
        h2Font = fontSettings.boldFont(ofSize: size + 6)
        h3Font = fontSettings.boldFont(ofSize: size + 3)
        h4Font = fontSettings.font(ofSize: size + 1, weight: .semibold)
        h5Font = fontSettings.font(ofSize: size, weight: .medium)
        h6Font = fontSettings.font(ofSize: size - 1, weight: .medium)
        boldFont = fontSettings.boldFont(ofSize: size)
        italicFont = fontSettings.italicFont(ofSize: size)
        boldItalicFont = fontSettings.boldItalicFont(ofSize: size)
        codeFont = fontSettings.font(ofSize: size - 1)
        currentFontFamily = fontSettings.fontFamily
        currentFontSize = fontSettings.fontSize
    }

    func highlight(_ textStorage: NSTextStorage) {
        guard !isHighlighting else { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string

        textStorage.beginEditing()

        // Reset to defaults
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: baseForeground
        ], range: fullRange)

        // Find fenced code block ranges
        let codeBlockRanges = findCodeBlockRanges(in: text)

        // Apply code block styling
        for range in codeBlockRanges {
            textStorage.addAttributes([
                .font: codeFont,
                .backgroundColor: Monokai.codeBlockBgNS
            ], range: range)
        }

        // Apply line-level patterns (skip code blocks)
        applyHeadings(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyBlockquotes(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyUnorderedLists(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyOrderedLists(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyCheckboxes(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)

        // Apply inline patterns (skip code blocks)
        applyBoldItalic(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyBold(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyItalic(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyInlineCode(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyStrikethrough(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)
        applyLinks(textStorage: textStorage, text: text, codeBlockRanges: codeBlockRanges)

        textStorage.endEditing()
    }

    // MARK: - Code Block Detection

    private func findCodeBlockRanges(in text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var blockStart = 0
        var currentOffset = 0

        for line in lines {
            let lineLength = (line as NSString).length
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    // End of code block (include this line)
                    let blockEnd = currentOffset + lineLength
                    ranges.append(NSRange(location: blockStart, length: blockEnd - blockStart))
                    inCodeBlock = false
                } else {
                    // Start of code block
                    blockStart = currentOffset
                    inCodeBlock = true
                }
            }
            currentOffset += lineLength + 1 // +1 for newline
        }

        // If code block wasn't closed, extend to end
        if inCodeBlock {
            ranges.append(NSRange(location: blockStart, length: (text as NSString).length - blockStart))
        }

        return ranges
    }

    private func isInCodeBlock(_ range: NSRange, codeBlockRanges: [NSRange]) -> Bool {
        for cbRange in codeBlockRanges {
            if NSIntersectionRange(cbRange, range).length > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Heading Styles

    private func applyHeadings(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        headingH1to3Regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            let hashRange = match.range(at: 1)
            let hashCount = hashRange.length

            let font: NSFont
            switch hashCount {
            case 1: font = h1Font
            case 2: font = h2Font
            default: font = h3Font
            }

            textStorage.addAttributes([
                .font: font,
                .foregroundColor: Monokai.keywordNS
            ], range: match.range)
        }

        headingH4to6Regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            let hashRange = match.range(at: 1)
            let hashCount = hashRange.length

            let font: NSFont
            switch hashCount {
            case 4: font = h4Font
            case 5: font = h5Font
            default: font = h6Font
            }

            textStorage.addAttributes([
                .font: font,
                .foregroundColor: Monokai.keywordNS
            ], range: match.range)
        }
    }

    // MARK: - Inline Styles

    private func applyBoldItalic(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        boldItalicRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .font: boldItalicFont,
                .foregroundColor: Monokai.functionNS
            ], range: match.range)
        }
    }

    private func applyBold(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        boldRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            // Skip if this is actually bold+italic (***text***)
            let range = match.range
            if range.location > 0 {
                let prevChar = (text as NSString).substring(with: NSRange(location: range.location - 1, length: 1))
                if prevChar == "*" { return }
            }
            if range.location + range.length < (text as NSString).length {
                let nextChar = (text as NSString).substring(with: NSRange(location: range.location + range.length, length: 1))
                if nextChar == "*" { return }
            }
            textStorage.addAttributes([
                .font: boldFont,
                .foregroundColor: Monokai.functionNS
            ], range: match.range)
        }
    }

    private func applyItalic(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        italicRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .font: italicFont,
                .foregroundColor: baseForeground
            ], range: match.range)
        }
    }

    private func applyInlineCode(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        inlineCodeRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .font: codeFont,
                .foregroundColor: Monokai.stringNS,
                .backgroundColor: Monokai.inlineCodeBgNS
            ], range: match.range)
        }
    }

    private func applyStrikethrough(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        strikethroughRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: Monokai.commentNS
            ], range: match.range)
        }
    }

    private func applyLinks(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        linkRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .foregroundColor: Monokai.typeNS,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range)
        }
    }

    // MARK: - Block-Level Styles

    private func applyBlockquotes(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        blockquoteRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            textStorage.addAttributes([
                .font: italicFont,
                .foregroundColor: Monokai.commentNS
            ], range: match.range)
        }
    }

    private func applyUnorderedLists(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        unorderedListRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            let markerRange = match.range(at: 1)
            textStorage.addAttribute(.foregroundColor, value: Monokai.keywordNS, range: markerRange)
        }
    }

    private func applyOrderedLists(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        orderedListRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }
            let numberRange = match.range(at: 1)
            textStorage.addAttribute(.foregroundColor, value: Monokai.numberNS, range: numberRange)
        }
    }

    private func applyCheckboxes(textStorage: NSTextStorage, text: String, codeBlockRanges: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        checkboxRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, !isInCodeBlock(match.range, codeBlockRanges: codeBlockRanges) else { return }

            let checkCharRange = match.range(at: 2)
            let checkChar = (text as NSString).substring(with: checkCharRange)
            let isChecked = checkChar == "x"

            // Style the whole checkbox marker
            let color = isChecked ? Monokai.keywordNS : Monokai.commentNS
            textStorage.addAttribute(.foregroundColor, value: color, range: match.range)

            // Mark the bracket area as clickable (from `[` to `]`)
            let bracketStart = match.range(at: 1).location + match.range(at: 1).length - 1 // the `[`
            let bracketEnd = match.range(at: 3).location + match.range(at: 3).length // after `]`
            let clickableRange = NSRange(location: bracketStart, length: bracketEnd - bracketStart)
            textStorage.addAttribute(.checkboxRange, value: clickableRange, range: clickableRange)
        }
    }
}
