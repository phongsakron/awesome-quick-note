import Foundation

final class CodeFormatter {
    /// Returns formatted code, or nil if language not supported or formatting failed.
    static func format(code: String, language: String?) -> String? {
        guard let lang = language?.lowercased() else { return nil }

        let formatted: String?
        switch lang {
        case "json":
            formatted = formatJSON(code)
        case "xml", "html", "svg":
            formatted = formatXML(code)
        case "javascript", "js", "typescript", "ts":
            formatted = formatJavaScript(code)
        default:
            return nil
        }

        guard var result = formatted else { return nil }

        // Preserve trailing newline — codeBlock.code ends with \n (before closing fence).
        // Formatters strip it, which causes the closing ``` to merge with the last line.
        if code.hasSuffix("\n") && !result.hasSuffix("\n") {
            result.append("\n")
        }

        return result
    }

    static var supportedLanguages: Set<String> {
        ["json", "xml", "html", "svg", "javascript", "js", "typescript", "ts"]
    }

    // MARK: - JSON

    private static func formatJSON(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validate it's actually JSON before formatting
        guard let data = trimmed.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }

        // Format by walking the raw string to preserve key order
        var result = ""
        var indentLevel = 0
        let indent = "  "
        var inString = false
        var escaped = false
        let chars = Array(trimmed)

        for i in 0..<chars.count {
            let char = chars[i]

            if escaped {
                escaped = false
                result.append(char)
                continue
            }

            if char == "\\" && inString {
                escaped = true
                result.append(char)
                continue
            }

            if char == "\"" {
                inString.toggle()
                result.append(char)
                continue
            }

            if inString {
                result.append(char)
                continue
            }

            // Skip existing whitespace outside strings
            if char.isWhitespace || char.isNewline {
                continue
            }

            switch char {
            case "{", "[":
                result.append(char)
                indentLevel += 1
                // Check if next non-whitespace is closing bracket (empty object/array)
                let next = nextNonWhitespace(in: chars, after: i)
                if next == "}" || next == "]" {
                    // Don't add newline for empty {} or []
                } else {
                    result.append("\n")
                    result.append(String(repeating: indent, count: indentLevel))
                }
            case "}", "]":
                indentLevel = max(0, indentLevel - 1)
                // Check if previous non-whitespace output was opening bracket
                let lastNonWS = result.last { !$0.isWhitespace && !$0.isNewline }
                if lastNonWS == "{" || lastNonWS == "[" {
                    // Empty object/array — no newline
                } else {
                    result.append("\n")
                    result.append(String(repeating: indent, count: indentLevel))
                }
                result.append(char)
            case ",":
                result.append(char)
                result.append("\n")
                result.append(String(repeating: indent, count: indentLevel))
            case ":":
                result.append(": ")
            default:
                result.append(char)
            }
        }

        return result
    }

    private static func nextNonWhitespace(in chars: [Character], after index: Int) -> Character? {
        var i = index + 1
        while i < chars.count {
            if !chars[i].isWhitespace && !chars[i].isNewline {
                return chars[i]
            }
            i += 1
        }
        return nil
    }

    // MARK: - XML

    private static func formatXML(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let doc = try? XMLDocument(xmlString: trimmed, options: [.nodePrettyPrint]) else { return nil }
        return doc.xmlString(options: [.nodePrettyPrint])
    }

    // MARK: - JavaScript / TypeScript

    private static func formatJavaScript(_ code: String) -> String? {
        let lines = code.components(separatedBy: "\n")
        var result: [String] = []
        var indentLevel = 0
        let indent = "  "

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append("")
                continue
            }

            // Decrease indent if line starts with a closing bracket
            if let first = trimmed.first, "}])".contains(first) {
                indentLevel = max(0, indentLevel - 1)
            }

            result.append(String(repeating: indent, count: indentLevel) + trimmed)

            // Adjust indent based on net brace count
            let net = netBraceCount(in: trimmed)
            if let first = trimmed.first, "}])".contains(first) {
                // We already decremented once for the leading close;
                // net includes that close, so add 1 to compensate.
                indentLevel = max(0, indentLevel + net + 1)
            } else {
                indentLevel = max(0, indentLevel + net)
            }
        }

        return result.joined(separator: "\n")
    }

    /// Count `{[(` minus `}])` in a line, skipping string literals and // comments.
    private static func netBraceCount(in line: String) -> Int {
        var net = 0
        var inString: Character? = nil
        var escaped = false
        let chars = Array(line)

        for i in 0..<chars.count {
            let char = chars[i]

            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString != nil {
                escaped = true
                continue
            }

            if let q = inString {
                if char == q { inString = nil }
                continue
            }

            // Line comment — stop counting
            if char == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                break
            }

            switch char {
            case "\"", "'", "`":
                inString = char
            case "{", "[", "(":
                net += 1
            case "}", "]", ")":
                net -= 1
            default:
                break
            }
        }

        return net
    }
}
