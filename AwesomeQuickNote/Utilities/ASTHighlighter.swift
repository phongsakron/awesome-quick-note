import AppKit
import Markdown

extension NSAttributedString.Key {
    static let checkboxRange = NSAttributedString.Key("checkboxRange")
    static let markdownLink = NSAttributedString.Key("markdownLink")
    static let markdownImageSource = NSAttributedString.Key("markdownImageSource")
}

struct HighlightResult {
    struct CodeBlockInfo {
        let language: String?
        let codeContent: String
        let fullRange: NSRange
    }
    struct ImageInfo {
        let source: String
        let range: NSRange
    }
    var codeBlocks: [CodeBlockInfo] = []
    var images: [ImageInfo] = []
}

final class ASTHighlighter {
    private var isHighlighting = false

    var baseFont: NSFont
    var h1Font: NSFont
    var h2Font: NSFont
    var h3Font: NSFont
    var h4Font: NSFont
    var h5Font: NSFont
    var h6Font: NSFont
    var boldFont: NSFont
    var italicFont: NSFont
    var boldItalicFont: NSFont
    var codeFont: NSFont

    private var currentFontFamily: String = ""
    private var currentFontSize: CGFloat = 0

    init(fontSettings: FontSettings? = nil) {
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
            let fm = NSFontManager.shared
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

    func highlight(_ textStorage: NSTextStorage) -> HighlightResult {
        guard !isHighlighting else { return HighlightResult() }
        isHighlighting = true
        defer { isHighlighting = false }

        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.beginEditing()

        // Reset to defaults
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: Monokai.foregroundNS
        ], range: fullRange)

        // Parse markdown AST
        let document = Document(parsing: text)
        let converter = SourceRangeConverter(string: text)

        var walker = HighlightWalker(
            textStorage: textStorage,
            converter: converter,
            highlighter: self
        )
        walker.visit(document)

        textStorage.endEditing()

        return walker.result
    }
}

// MARK: - HighlightWalker

private struct HighlightWalker: MarkupWalker {
    let textStorage: NSTextStorage
    let converter: SourceRangeConverter
    let highlighter: ASTHighlighter
    let text: String
    var result = HighlightResult()

    init(textStorage: NSTextStorage, converter: SourceRangeConverter, highlighter: ASTHighlighter) {
        self.textStorage = textStorage
        self.converter = converter
        self.highlighter = highlighter
        self.text = textStorage.string
    }

    // MARK: - Headings

    mutating func visitHeading(_ heading: Heading) {
        guard let range = converter.nsRange(for: heading),
              range.location + range.length <= textStorage.length else {
            descendInto(heading)
            return
        }

        let font: NSFont
        switch heading.level {
        case 1: font = highlighter.h1Font
        case 2: font = highlighter.h2Font
        case 3: font = highlighter.h3Font
        case 4: font = highlighter.h4Font
        case 5: font = highlighter.h5Font
        default: font = highlighter.h6Font
        }

        textStorage.addAttributes([
            .font: font,
            .foregroundColor: Monokai.keywordNS
        ], range: range)

        descendInto(heading)
    }

    // MARK: - Strong (Bold)

    mutating func visitStrong(_ strong: Strong) {
        guard let range = converter.nsRange(for: strong),
              range.location + range.length <= textStorage.length else {
            descendInto(strong)
            return
        }

        textStorage.addAttributes([
            .font: highlighter.boldFont,
            .foregroundColor: Monokai.functionNS
        ], range: range)

        descendInto(strong)
    }

    // MARK: - Emphasis (Italic)

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        guard let range = converter.nsRange(for: emphasis),
              range.location + range.length <= textStorage.length else {
            descendInto(emphasis)
            return
        }

        let isInsideStrong = emphasis.parent is Strong
        let font = isInsideStrong ? highlighter.boldItalicFont : highlighter.italicFont
        let color = isInsideStrong ? Monokai.functionNS : Monokai.foregroundNS

        textStorage.addAttributes([
            .font: font,
            .foregroundColor: color
        ], range: range)

        descendInto(emphasis)
    }

    // MARK: - Inline Code

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        guard let range = converter.nsRange(for: inlineCode),
              range.location + range.length <= textStorage.length else {
            return
        }

        textStorage.addAttributes([
            .font: highlighter.codeFont,
            .foregroundColor: Monokai.stringNS,
            .backgroundColor: Monokai.inlineCodeBgNS
        ], range: range)
    }

    // MARK: - Code Block

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = converter.nsRange(for: codeBlock),
              range.location + range.length <= textStorage.length else {
            return
        }

        textStorage.addAttributes([
            .font: highlighter.codeFont,
            .backgroundColor: Monokai.codeBlockBgNS
        ], range: range)

        result.codeBlocks.append(HighlightResult.CodeBlockInfo(
            language: codeBlock.language,
            codeContent: codeBlock.code,
            fullRange: range
        ))
    }

    // MARK: - Strikethrough

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        guard let range = converter.nsRange(for: strikethrough),
              range.location + range.length <= textStorage.length else {
            descendInto(strikethrough)
            return
        }

        textStorage.addAttributes([
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: Monokai.commentNS
        ], range: range)

        descendInto(strikethrough)
    }

    // MARK: - Links

    mutating func visitLink(_ link: Link) {
        guard let range = converter.nsRange(for: link),
              range.location + range.length <= textStorage.length else {
            descendInto(link)
            return
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: Monokai.typeNS,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        // Use custom attribute instead of .link to avoid NSTextView's
        // internal link handling which can crash during drawing
        if let destination = link.destination {
            attrs[.markdownLink] = destination
        }

        textStorage.addAttributes(attrs, range: range)

        descendInto(link)
    }

    // MARK: - Images

    mutating func visitImage(_ image: Markdown.Image) {
        guard let range = converter.nsRange(for: image),
              range.location + range.length <= textStorage.length else {
            return
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: Monokai.typeNS
        ]

        if let source = image.source {
            attrs[.markdownImageSource] = source
            result.images.append(HighlightResult.ImageInfo(
                source: source,
                range: range
            ))
        }

        textStorage.addAttributes(attrs, range: range)
    }

    // MARK: - Block Quote

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        guard let range = converter.nsRange(for: blockQuote),
              range.location + range.length <= textStorage.length else {
            descendInto(blockQuote)
            return
        }

        textStorage.addAttributes([
            .font: highlighter.italicFont,
            .foregroundColor: Monokai.commentNS
        ], range: range)

        descendInto(blockQuote)
    }

    // MARK: - List Items

    mutating func visitListItem(_ listItem: ListItem) {
        guard let range = converter.nsRange(for: listItem),
              range.location + range.length <= textStorage.length else {
            descendInto(listItem)
            return
        }

        // Check if this is a checkbox list item
        if let checkbox = listItem.checkbox {
            let isChecked = checkbox == .checked

            let nsText = text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsText.substring(with: lineRange)

            if let bracketRange = lineText.range(of: isChecked ? "[x]" : "[ ]") {
                let bracketNSRange = NSRange(bracketRange, in: lineText)
                let absoluteRange = NSRange(
                    location: lineRange.location + bracketNSRange.location,
                    length: bracketNSRange.length
                )

                let color = isChecked ? Monokai.keywordNS : Monokai.commentNS
                textStorage.addAttribute(.foregroundColor, value: color, range: absoluteRange)
                textStorage.addAttribute(.checkboxRange, value: absoluteRange, range: absoluteRange)
            }
        }

        // Style the list marker
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
        let lineText = nsText.substring(with: lineRange)

        if listItem.parent is UnorderedList {
            if let markerMatch = lineText.range(of: "^(\\s*[-*+])", options: .regularExpression) {
                let markerNSRange = NSRange(markerMatch, in: lineText)
                let absoluteRange = NSRange(
                    location: lineRange.location + markerNSRange.location,
                    length: markerNSRange.length
                )
                if absoluteRange.location + absoluteRange.length <= textStorage.length {
                    textStorage.addAttribute(.foregroundColor, value: Monokai.keywordNS, range: absoluteRange)
                }
            }
        } else if listItem.parent is OrderedList {
            if let markerMatch = lineText.range(of: "^(\\s*\\d+\\.)", options: .regularExpression) {
                let markerNSRange = NSRange(markerMatch, in: lineText)
                let absoluteRange = NSRange(
                    location: lineRange.location + markerNSRange.location,
                    length: markerNSRange.length
                )
                if absoluteRange.location + absoluteRange.length <= textStorage.length {
                    textStorage.addAttribute(.foregroundColor, value: Monokai.numberNS, range: absoluteRange)
                }
            }
        }

        descendInto(listItem)
    }
}
