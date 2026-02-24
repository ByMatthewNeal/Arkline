import Foundation

// MARK: - Markdown Format

/// Supported markdown formatting types for the broadcast editor toolbar.
enum MarkdownFormat: CaseIterable {
    case bold
    case italic
    case underline
    case strikethrough
    case link
    case orderedList
    case unorderedList
}

// MARK: - Markdown Formatter

/// Pure logic for applying markdown formatting to text with a selected range.
enum MarkdownFormatter {

    /// Result of applying a format: the updated full text and the new selection range.
    struct Result {
        let newText: String
        let newSelection: NSRange
    }

    /// Apply the given markdown format to `text` around `selectedRange`.
    static func apply(_ format: MarkdownFormat, to text: String, selectedRange: NSRange) -> Result {
        switch format {
        case .bold:
            return wrapInline(text: text, range: selectedRange, prefix: "**", suffix: "**")
        case .italic:
            return wrapInline(text: text, range: selectedRange, prefix: "*", suffix: "*")
        case .underline:
            return wrapInline(text: text, range: selectedRange, prefix: "<u>", suffix: "</u>")
        case .strikethrough:
            return wrapInline(text: text, range: selectedRange, prefix: "~~", suffix: "~~")
        case .link:
            return applyLink(text: text, range: selectedRange)
        case .orderedList:
            return applyListPrefix(text: text, range: selectedRange, ordered: true)
        case .unorderedList:
            return applyListPrefix(text: text, range: selectedRange, ordered: false)
        }
    }

    // MARK: - Inline Wrap

    /// Wraps the selected text with prefix/suffix markers.
    /// If nothing is selected, inserts empty markers and places cursor between them.
    private static func wrapInline(text: String, range: NSRange, prefix: String, suffix: String) -> Result {
        let nsText = text as NSString
        let selected = nsText.substring(with: range)

        let replacement = "\(prefix)\(selected)\(suffix)"
        let newText = nsText.replacingCharacters(in: range, with: replacement)

        let newSelection: NSRange
        if range.length == 0 {
            // No selection: place cursor between markers
            newSelection = NSRange(location: range.location + prefix.count, length: 0)
        } else {
            // Selection exists: select the wrapped text (inside markers)
            newSelection = NSRange(location: range.location + prefix.count, length: selected.count)
        }

        return Result(newText: newText, newSelection: newSelection)
    }

    // MARK: - Link

    /// Wraps selected text as `[text](url)` and selects "url" for quick replacement.
    private static func applyLink(text: String, range: NSRange) -> Result {
        let nsText = text as NSString
        let selected = nsText.substring(with: range)

        let linkText = selected.isEmpty ? "link text" : selected
        let replacement = "[\(linkText)](url)"
        let newText = nsText.replacingCharacters(in: range, with: replacement)

        // Select "url" so the user can type the actual URL immediately
        let urlStart = range.location + 1 + linkText.count + 2 // past "[linkText]("
        let newSelection = NSRange(location: urlStart, length: 3) // "url"

        return Result(newText: newText, newSelection: newSelection)
    }

    // MARK: - List Prefix

    /// Inserts list prefixes (`1. ` or `- `) at the beginning of each line in the selection.
    private static func applyListPrefix(text: String, range: NSRange, ordered: Bool) -> Result {
        let nsText = text as NSString

        // Find the start of the first line and end of the last line in the selection
        let selectionEnd = range.location + range.length
        let lineRange = nsText.lineRange(for: range)

        let linesSubstring = nsText.substring(with: lineRange)
        let lines = linesSubstring.components(separatedBy: "\n")

        var newLines: [String] = []
        var lineNumber = 1

        for (index, line) in lines.enumerated() {
            // Skip empty trailing element from split
            if index == lines.count - 1 && line.isEmpty {
                newLines.append(line)
                continue
            }

            let prefix = ordered ? "\(lineNumber). " : "- "

            // Check if line already has a list prefix — toggle it off
            if ordered, let match = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                newLines.append(String(line[match.upperBound...]))
            } else if !ordered && line.hasPrefix("- ") {
                newLines.append(String(line.dropFirst(2)))
            } else {
                newLines.append(prefix + line)
                lineNumber += 1
            }
        }

        let replacement = newLines.joined(separator: "\n")
        let newText = nsText.replacingCharacters(in: lineRange, with: replacement)

        // Place cursor at end of modified region
        let newSelection = NSRange(location: lineRange.location + replacement.count, length: 0)

        return Result(newText: newText, newSelection: newSelection)
    }
}
