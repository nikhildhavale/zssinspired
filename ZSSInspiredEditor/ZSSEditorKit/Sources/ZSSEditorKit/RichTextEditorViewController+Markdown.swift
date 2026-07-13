import UIKit

/// Inline formatting accumulated while parsing markdown spans.
private struct MarkdownInlineStyle {
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    var link: URL?
}

// MARK: - Markdown export

extension RichTextEditorViewController {

    func attributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        var markdown = ""
        var index = 0
        let attributedText = attributedString

        while index < attributedText.length {
            var effectiveRange = NSRange(location: 0, length: 0)

            if let mention = attributedText.attribute(.zssMentionItem, at: index, effectiveRange: &effectiveRange) as? any MentionItem {
                markdown += "\(mentionTrigger(in: attributedText, at: index).symbol)\(mention.mentionDisplayName)"
            } else if let hashtag = attributedText.attribute(.zssHashtagItem, at: index, effectiveRange: &effectiveRange) as? any HashtagItem {
                markdown += "\(MentionTrigger.hash.symbol)\(hashtag.hashtagDisplayName)"
            } else if attributedText.attribute(.attachment, at: index, effectiveRange: &effectiveRange) is NSTextAttachment {
                markdown += "[image]"
            } else {
                let text = attributedText.attributedSubstring(from: effectiveRange).string
                var core = text
                var trailingNewlines = ""
                while core.hasSuffix("\n") {
                    core.removeLast()
                    trailingNewlines += "\n"
                }

                var formattedText = core

                if !core.isEmpty {
                    if let font = attributedText.attribute(.font, at: index, effectiveRange: nil) as? UIFont {
                        if let headingPrefix = headingMarkdownPrefix(for: font) {
                            formattedText = core
                                .components(separatedBy: "\n")
                                .map { $0.isEmpty ? $0 : headingPrefix + $0 }
                                .joined(separator: "\n")
                        } else {
                            let traits = font.fontDescriptor.symbolicTraits
                            if traits.contains(.traitBold) {
                                formattedText = "**\(formattedText)**"
                            }
                            if traits.contains(.traitItalic) {
                                formattedText = "*\(formattedText)*"
                            }
                        }
                    }

                    if attributedText.attribute(.underlineStyle, at: index, effectiveRange: nil) != nil {
                        formattedText = "__\(formattedText)__"
                    }

                    if attributedText.attribute(.strikethroughStyle, at: index, effectiveRange: nil) != nil {
                        formattedText = "~~\(formattedText)~~"
                    }

                    if let link = attributedText.attribute(.link, at: index, effectiveRange: nil) as? URL {
                        formattedText = "[\(formattedText)](\(link.absoluteString))"
                    }
                }

                markdown += formattedText + trailingNewlines
            }
            index = effectiveRange.upperBound
        }

        let indentLevels = paragraphIndentLevels(of: attributedText)
        return markdown
            .components(separatedBy: "\n")
            .enumerated()
            .map { lineIndex, line in
                var converted = line.replacingOccurrences(of: #"^(\s*)•\s?"#, with: "$1- ", options: .regularExpression)
                let level = lineIndex < indentLevels.count ? indentLevels[lineIndex] : 0
                let isListLine = converted.range(of: #"^\s*(-|\d+\.)\s"#, options: .regularExpression) != nil
                if level > 0 && isListLine {
                    converted = String(repeating: "    ", count: level) + converted
                }
                return converted
            }
            .joined(separator: "\n")
    }

    private func headingMarkdownPrefix(for font: UIFont) -> String? {
        guard font.fontDescriptor.symbolicTraits.contains(.traitBold) else { return nil }
        let headingLevels: [(style: HeadingStyle, level: Int)] = [(.h1, 1), (.h2, 2), (.h3, 3), (.h4, 4), (.h5, 5)]
        for entry in headingLevels where abs(font.pointSize - entry.style.pointSize) < 0.5 {
            return String(repeating: "#", count: entry.level) + " "
        }
        return nil
    }

    /// Indent level per paragraph (split on "\n"), derived from the 24pt steps applied by indent/outdent.
    private func paragraphIndentLevels(of attributedString: NSAttributedString) -> [Int] {
        let nsString = attributedString.string as NSString
        var levels: [Int] = []
        var location = 0
        while true {
            if location < nsString.length,
               let style = attributedString.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle {
                levels.append(max(0, Int((style.headIndent / 24).rounded())))
            } else {
                levels.append(0)
            }
            let remaining = NSRange(location: location, length: nsString.length - location)
            let newlineRange = nsString.range(of: "\n", options: [], range: remaining)
            if newlineRange.location == NSNotFound { break }
            location = newlineRange.location + 1
        }
        return levels
    }
}

// MARK: - Markdown import

extension RichTextEditorViewController {

    /// Inverse of `attributedStringToMarkdown`: builds the attributed string
    /// shown in edit mode from the markdown dialect this editor emits.
    func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            var remainder = Substring(line)

            var indentLevel = 0
            while remainder.hasPrefix("    ") {
                indentLevel += 1
                remainder = remainder.dropFirst(4)
            }

            var headingStyle = HeadingStyle.paragraph
            let hashes = remainder.prefix(while: { $0 == "#" })
            if (1...6).contains(hashes.count), remainder.dropFirst(hashes.count).hasPrefix(" ") {
                headingStyle = [.h1, .h2, .h3, .h4, .h5, .h6][hashes.count - 1]
                remainder = remainder.dropFirst(hashes.count + 1)
            }

            let lineFont = headingStyle == .paragraph
                ? baseFont
                : fontMatching(baseFont, pointSize: headingStyle.pointSize, forceBold: true)
            let plainAttributes = markdownInlineAttributes(MarkdownInlineStyle(), lineFont: lineFont)

            let lineString = NSMutableAttributedString()
            if headingStyle == .paragraph, remainder.hasPrefix("- ") {
                remainder = remainder.dropFirst(2)
                lineString.append(NSAttributedString(string: "• ", attributes: plainAttributes))
            }
            lineString.append(markdownInlineAttributedString(from: remainder, style: MarkdownInlineStyle(), lineFont: lineFont))
            if index < lines.count - 1 {
                lineString.append(NSAttributedString(string: "\n", attributes: plainAttributes))
            }

            let paragraphStyle = (defaultParagraphStyle().mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = CGFloat(indentLevel) * 24
            paragraphStyle.headIndent = CGFloat(indentLevel) * 24
            lineString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: lineString.length))

            result.append(lineString)
        }

        return result
    }

    private func markdownInlineAttributedString(from text: Substring, style: MarkdownInlineStyle, lineFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remainder = text
        var plain = ""

        func flushPlain() {
            guard !plain.isEmpty else { return }
            result.append(NSAttributedString(string: plain, attributes: markdownInlineAttributes(style, lineFont: lineFont)))
            plain = ""
        }

        while !remainder.isEmpty {
            if remainder.first == "[", let link = parseMarkdownLink(remainder) {
                flushPlain()
                var linkStyle = style
                linkStyle.link = link.url
                result.append(markdownInlineAttributedString(from: link.label, style: linkStyle, lineFont: lineFont))
                remainder = link.remainder
                continue
            }

            if let span = matchMarkdownDelimiter(remainder) {
                flushPlain()
                var innerStyle = style
                span.apply(&innerStyle)
                result.append(markdownInlineAttributedString(from: span.content, style: innerStyle, lineFont: lineFont))
                remainder = span.remainder
                continue
            }

            plain.append(remainder.removeFirst())
        }

        flushPlain()
        return result
    }

    /// Matches a `[label](url)` span at the start of `text`.
    private func parseMarkdownLink(_ text: Substring) -> (label: Substring, url: URL, remainder: Substring)? {
        guard
            text.first == "[",
            let closeBracket = text.firstIndex(of: "]")
        else { return nil }

        let afterBracket = text.index(after: closeBracket)
        guard afterBracket < text.endIndex, text[afterBracket] == "(" else { return nil }

        let urlStart = text.index(after: afterBracket)
        guard let closeParen = text[urlStart...].firstIndex(of: ")") else { return nil }

        let urlText = String(text[urlStart..<closeParen])
        guard !urlText.isEmpty, let url = URL(string: urlText) else { return nil }

        let label = text[text.index(after: text.startIndex)..<closeBracket]
        return (label, url, text[text.index(after: closeParen)...])
    }

    /// Matches a delimited span (`***`, `**`, `__`, `~~` or `*`) at the start
    /// of `text`. `***` is checked first so bold+italic round-trips.
    private func matchMarkdownDelimiter(_ text: Substring) -> (content: Substring, remainder: Substring, apply: (inout MarkdownInlineStyle) -> Void)? {
        let delimiters: [(token: String, apply: (inout MarkdownInlineStyle) -> Void)] = [
            ("***", { $0.bold = true; $0.italic = true }),
            ("**", { $0.bold = true }),
            ("__", { $0.underline = true }),
            ("~~", { $0.strikethrough = true }),
            ("*", { $0.italic = true })
        ]

        for delimiter in delimiters {
            guard text.hasPrefix(delimiter.token) else { continue }
            let inner = text.dropFirst(delimiter.token.count)
            guard let closeRange = inner.range(of: delimiter.token), closeRange.lowerBound > inner.startIndex else { continue }
            return (inner[..<closeRange.lowerBound], inner[closeRange.upperBound...], delimiter.apply)
        }

        return nil
    }

    private func markdownInlineAttributes(_ style: MarkdownInlineStyle, lineFont: UIFont) -> [NSAttributedString.Key: Any] {
        var traits = lineFont.fontDescriptor.symbolicTraits
        if style.bold { traits.insert(.traitBold) }
        if style.italic { traits.insert(.traitItalic) }
        let descriptor = lineFont.fontDescriptor.withSymbolicTraits(traits) ?? lineFont.fontDescriptor

        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(descriptor: descriptor, size: lineFont.pointSize),
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle()
        ]
        if style.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if style.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = style.link {
            attributes[.link] = link
            attributes[.foregroundColor] = linkColor
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }
}
