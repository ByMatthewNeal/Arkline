import SwiftUI

// MARK: - Markdown Content View

/// Renders markdown-formatted broadcast content for the reader side.
/// Supports: **bold**, *italic*, ~~strikethrough~~, <u>underline</u>, [links](url),
/// ordered lists (1. ), and unordered lists (- ).
/// Plain text (no markdown) renders identically to the previous Text-based display.
struct MarkdownContentView: View {
    let content: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Block Parsing

    private enum ContentBlock {
        case paragraph(String)
        case orderedList([String])
        case unorderedList([String])
        case heading(level: Int, text: String)
        case blockquote(String)
    }

    /// Splits content into blocks: paragraphs, ordered list groups, unordered list groups.
    private func parseBlocks() -> [ContentBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [ContentBlock] = []
        var currentOL: [String] = []
        var currentUL: [String] = []
        var currentParagraph: [String] = []

        func flushParagraph() {
            if !currentParagraph.isEmpty {
                blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                currentParagraph = []
            }
        }

        func flushOL() {
            if !currentOL.isEmpty {
                blocks.append(.orderedList(currentOL))
                currentOL = []
            }
        }

        func flushUL() {
            if !currentUL.isEmpty {
                blocks.append(.unorderedList(currentUL))
                currentUL = []
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let match = trimmed.range(of: #"^(#{1,3})\s+"#, options: .regularExpression) {
                flushParagraph()
                flushOL()
                flushUL()
                let hashCount = trimmed[trimmed.startIndex..<match.upperBound].filter { $0 == "#" }.count
                blocks.append(.heading(level: hashCount, text: String(trimmed[match.upperBound...])))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph()
                flushOL()
                flushUL()
                blocks.append(.blockquote(String(trimmed.dropFirst(2))))
            } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                flushParagraph()
                flushUL()
                currentOL.append(String(trimmed[match.upperBound...]))
            } else if trimmed.hasPrefix("- ") {
                flushParagraph()
                flushOL()
                currentUL.append(String(trimmed.dropFirst(2)))
            } else {
                flushOL()
                flushUL()
                currentParagraph.append(line)
            }
        }

        flushParagraph()
        flushOL()
        flushUL()

        return blocks
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: ContentBlock) -> some View {
        switch block {
        case .paragraph(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(parseInlineMarkdown(text))
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .tint(AppColors.accent)
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: ArkSpacing.xs) {
                        Text("\(index + 1).")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 22, alignment: .trailing)

                        Text(parseInlineMarkdown(item))
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .tint(AppColors.accent)
                    }
                }
            }

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: ArkSpacing.xs) {
                        Text("\u{2022}")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 22, alignment: .center)

                        Text(parseInlineMarkdown(item))
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .tint(AppColors.accent)
                    }
                }
            }

        case .heading(let level, let text):
            Text(parseInlineMarkdown(text))
                .font(.system(size: level == 1 ? 22 : level == 2 ? 18 : 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .tint(AppColors.accent)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: ArkSpacing.sm) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppColors.accent)
                    .frame(width: 3)

                Text(parseInlineMarkdown(text))
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .tint(AppColors.accent)
            }
        }
    }

    // MARK: - Inline Markdown Parsing

    /// Parses inline markdown into an `AttributedString`.
    /// Handles: **bold**, *italic*, ~~strikethrough~~, <u>underline</u>, [text](url)
    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = text

        // Build attributed string by processing markdown tokens
        var attributed = AttributedString()

        // Use a regex-based approach to handle inline formatting
        // Process the string sequentially, handling nested formatting
        let scanner = MarkdownInlineScanner(input: result)
        attributed = scanner.parse(
            baseColor: AppColors.textPrimary(colorScheme),
            accentColor: AppColors.accent
        )

        return attributed
    }
}

// MARK: - Inline Markdown Scanner

/// Scans markdown inline formatting and produces an `AttributedString`.
private struct MarkdownInlineScanner {
    let input: String

    func parse(baseColor: Color, accentColor: Color) -> AttributedString {
        var result = AttributedString()
        var remaining = input[input.startIndex...]

        while !remaining.isEmpty {
            // Try to match each pattern at the current position
            if let match = matchPattern(&remaining, pattern: "**", tag: .bold) {
                var attr = parse(substring: match, baseColor: baseColor, accentColor: accentColor)
                attr.mergeAttributes(boldAttributes())
                result.append(attr)
            } else if let match = matchPattern(&remaining, pattern: "~~", tag: .strikethrough) {
                var attr = parse(substring: match, baseColor: baseColor, accentColor: accentColor)
                attr.mergeAttributes(strikethroughAttributes())
                result.append(attr)
            } else if let match = matchHTMLTag(&remaining, open: "<u>", close: "</u>") {
                var attr = parse(substring: match, baseColor: baseColor, accentColor: accentColor)
                attr.mergeAttributes(underlineAttributes())
                result.append(attr)
            } else if let (text, url) = matchLink(&remaining) {
                var attr = AttributedString(text)
                if let linkURL = URL(string: url) {
                    attr.link = linkURL
                    attr.foregroundColor = accentColor
                }
                result.append(attr)
            } else if let match = matchSinglePattern(&remaining, pattern: "*", tag: .italic) {
                var attr = parse(substring: match, baseColor: baseColor, accentColor: accentColor)
                attr.mergeAttributes(italicAttributes())
                result.append(attr)
            } else {
                // Consume one character as plain text
                var plain = AttributedString(String(remaining.first!))
                result.append(plain)
                remaining = remaining.dropFirst()
            }
        }

        return result
    }

    private func parse(substring: String, baseColor: Color, accentColor: Color) -> AttributedString {
        let scanner = MarkdownInlineScanner(input: substring)
        return scanner.parse(baseColor: baseColor, accentColor: accentColor)
    }

    private enum InlineTag {
        case bold, italic, strikethrough
    }

    /// Match a symmetric double-char pattern like `**...**` or `~~...~~`
    private func matchPattern(_ remaining: inout Substring, pattern: String, tag: InlineTag) -> String? {
        guard remaining.hasPrefix(pattern) else { return nil }
        let afterOpen = remaining.dropFirst(pattern.count)
        guard let closeRange = afterOpen.range(of: pattern) else { return nil }
        let content = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
        guard !content.isEmpty else { return nil }
        remaining = afterOpen[closeRange.upperBound...]
        return content
    }

    /// Match a single-char pattern like `*...*` — must not match `**`
    private func matchSinglePattern(_ remaining: inout Substring, pattern: String, tag: InlineTag) -> String? {
        guard remaining.hasPrefix(pattern) else { return nil }
        // Make sure it's not `**`
        let afterFirst = remaining.dropFirst(pattern.count)
        if afterFirst.hasPrefix(pattern) { return nil }
        guard let closeIndex = afterFirst.firstIndex(of: Character(pattern)) else { return nil }
        let content = String(afterFirst[afterFirst.startIndex..<closeIndex])
        guard !content.isEmpty else { return nil }
        remaining = afterFirst[afterFirst.index(after: closeIndex)...]
        return content
    }

    /// Match HTML-style tags like `<u>...</u>`
    private func matchHTMLTag(_ remaining: inout Substring, open: String, close: String) -> String? {
        guard remaining.hasPrefix(open) else { return nil }
        let afterOpen = remaining.dropFirst(open.count)
        guard let closeRange = afterOpen.range(of: close) else { return nil }
        let content = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
        guard !content.isEmpty else { return nil }
        remaining = afterOpen[closeRange.upperBound...]
        return content
    }

    /// Match `[text](url)`
    private func matchLink(_ remaining: inout Substring) -> (text: String, url: String)? {
        guard remaining.hasPrefix("[") else { return nil }
        let afterBracket = remaining.dropFirst()
        guard let closeBracket = afterBracket.firstIndex(of: "]") else { return nil }
        let text = String(afterBracket[afterBracket.startIndex..<closeBracket])

        let afterClose = afterBracket[afterBracket.index(after: closeBracket)...]
        guard afterClose.hasPrefix("(") else { return nil }
        let afterParen = afterClose.dropFirst()
        guard let closeParen = afterParen.firstIndex(of: ")") else { return nil }
        let url = String(afterParen[afterParen.startIndex..<closeParen])

        remaining = afterParen[afterParen.index(after: closeParen)...]
        return (text, url)
    }

    // MARK: - Attribute Containers

    private func boldAttributes() -> AttributeContainer {
        var container = AttributeContainer()
        container.font = AppFonts.interUIFont(size: 14, weight: .bold)
        return container
    }

    private func italicAttributes() -> AttributeContainer {
        var container = AttributeContainer()
        container.font = AppFonts.interUIFont(size: 14, weight: .regular, italic: true)
        return container
    }

    private func strikethroughAttributes() -> AttributeContainer {
        var container = AttributeContainer()
        container.strikethroughStyle = .single
        return container
    }

    private func underlineAttributes() -> AttributeContainer {
        var container = AttributeContainer()
        container.underlineStyle = .single
        return container
    }
}

// MARK: - AppFonts UIFont Helper

extension AppFonts {
    #if canImport(UIKit)
    /// Creates a UIFont for use in AttributedString containers.
    static func interUIFont(size: CGFloat, weight: UIFont.Weight, italic: Bool = false) -> UIFont {
        let fontName: String
        switch weight {
        case .bold: fontName = "Inter-Bold"
        case .semibold: fontName = "Inter-SemiBold"
        case .medium: fontName = "Inter-Medium"
        default: fontName = italic ? "Inter-Italic" : "Inter-Regular"
        }

        if let font = UIFont(name: fontName, size: size) {
            if italic && weight != .regular {
                // Apply italic trait to weighted font
                let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor
                return UIFont(descriptor: descriptor, size: size)
            }
            return font
        }

        // Fallback to system font
        if italic {
            return UIFont.italicSystemFont(ofSize: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    #endif
}
