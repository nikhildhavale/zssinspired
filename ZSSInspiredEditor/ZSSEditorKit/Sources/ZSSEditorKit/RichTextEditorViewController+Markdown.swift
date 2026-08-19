import UIKit

/// A list marker parsed off the front of a markdown line during import.
private struct MarkdownListMarker {
    enum Kind {
        case bullet
        case ordered
    }

    var kind: Kind
    /// Column the item's content starts at — what decides whether the marker
    /// on the *next* line is a child of this item or a sibling of it.
    var contentColumn: Int
    /// The authored number of an ordered item, so an imported list starts
    /// counting where the source said it does.
    var number: Int
    /// The line past the marker and its trailing gap.
    var remainder: Substring
}

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
                let trigger = mentionTrigger(in: attributedText, at: index)
                switch mentionConfiguration.exportFormat {
                case .anchor:
                    markdown += "\(trigger.symbol)\(mention.mentionDisplayName)"
                case .custom(let formatter):
                    let escapedName = escapedHTMLText(mention.mentionDisplayName)
                    let escapedIdentifier = escapedHTMLAttribute(mention.mentionIdentifier)
                    markdown += formatter(mention, escapedName, escapedIdentifier)
                }
            } else if let hashtag = attributedText.attribute(.zssHashtagItem, at: index, effectiveRange: &effectiveRange) as? any HashtagItem {
                markdown += "\(MentionTrigger.hash.symbol)\(hashtag.hashtagDisplayName)"
            } else if attributedText.attribute(.zssBulletMarkerAttachment, at: index, effectiveRange: &effectiveRange) != nil {
                // A placeholder for the bullet-normalization pass below
                // (which matches `String.bulletGlyphPattern`), not a
                // character that ends up in the stored markdown — that pass
                // collapses it (plus the marker's trailing `listMarkerGap`)
                // down to the canonical "- ".
                markdown += "•"
            } else if attributedText.attribute(.attachment, at: index, effectiveRange: &effectiveRange) is NSTextAttachment {
                markdown += "[image]"
            } else {
                // A run's attributes (e.g. bold) commonly stay unchanged
                // across a "\n" — the same bold style continuing into the
                // next bulleted line, say — so effectiveRange can span
                // multiple lines/list items even though each needs its own
                // delimiters. A *uniform* run's reported range doesn't
                // depend on where within it we query, so it can start
                // before `index` too — rebuild the range anchored at
                // `index`, capped at the first newline (keeping any
                // further *consecutive* newlines with it, so multiple
                // blank lines still fall through the trailing-newline
                // stripping below) so emphasis is never wrapped around an
                // embedded line/paragraph break.
                let runEnd = effectiveRange.upperBound
                let nsString = attributedText.string as NSString
                var chunkEnd = runEnd
                let newlineRange = nsString.range(of: "\n", options: [], range: NSRange(location: index, length: runEnd - index))
                if newlineRange.location != NSNotFound {
                    chunkEnd = newlineRange.location + newlineRange.length
                    while chunkEnd < runEnd, nsString.character(at: chunkEnd) == 10 {
                        chunkEnd += 1
                    }
                }
                effectiveRange = NSRange(location: index, length: chunkEnd - index)

                let text = attributedText.attributedSubstring(from: effectiveRange).string
                var core = text
                var trailingNewlines = ""
                while core.hasSuffix("\n") {
                    core.removeLast()
                    trailingNewlines += "\n"
                }

                var formattedText = core

                if !core.isEmpty {
                    if let rawHeadingStyle = attributedText.attribute(.zssHeadingStyle, at: index, effectiveRange: nil) as? String,
                       let headingLevel = HeadingStyle(rawValue: rawHeadingStyle)?.level {
                        let headingPrefix = String(repeating: "#", count: headingLevel) + " "
                        formattedText = core
                            .components(separatedBy: "\n")
                            .map { $0.isEmpty ? $0 : headingPrefix + $0 }
                            .joined(separator: "\n")
                    } else {
                        // Emphasis delimiters can't be directly adjacent to
                        // whitespace per CommonMark (e.g. "**bold **" won't
                        // parse as bold) — trim the span being wrapped and
                        // reattach the whitespace outside every delimiter
                        // instead of inside the innermost one. A leading
                        // "•"/"1." list marker (which can carry the same
                        // bold/italic attributes as the rest of the line,
                        // e.g. a fully-bold list item) is excluded the same
                        // way: wrapped inside the delimiters it wouldn't be
                        // recognized as a list marker by the bullet/number
                        // post-processing below, which only matches at the
                        // very start of the line.
                        let leadingMarkerRange = core.range(of: "^\\s*(\(String.bulletGlyphPattern)|\\d+\\.)\\s*", options: .regularExpression)
                        let leadingSpace = leadingMarkerRange.map { String(core[$0]) } ?? String(core.prefix(while: { $0 == " " }))
                        let trailingSpace = String(core.reversed().prefix(while: { $0 == " " }).reversed())
                        var wrapped = String(core.dropFirst(leadingSpace.count).dropLast(trailingSpace.count))

                        // A link's own visual underline (`markdownInlineAttributes`/
                        // `linkTypingAttributes` set it automatically) isn't the
                        // user asking for "__underline__" markdown — skip the
                        // wrap for link runs so `[text](url)` round-trips
                        // instead of drifting to `[__text__](url)` on every export.
                        let isLink = attributedText.attribute(.link, at: index, effectiveRange: nil) != nil

                        if !wrapped.isEmpty {
                            if let font = attributedText.attribute(.font, at: index, effectiveRange: nil) as? UIFont {
                                let traits = font.fontDescriptor.symbolicTraits
                                if traits.contains(.traitBold) {
                                    wrapped = "**\(wrapped)**"
                                }
                                if traits.contains(.traitItalic) {
                                    wrapped = "*\(wrapped)*"
                                }
                            }
                            if !isLink, attributedText.attribute(.underlineStyle, at: index, effectiveRange: nil) != nil {
                                wrapped = "__\(wrapped)__"
                            }
                            if attributedText.attribute(.strikethroughStyle, at: index, effectiveRange: nil) != nil {
                                wrapped = "~~\(wrapped)~~"
                            }
                        }

                        formattedText = leadingSpace + wrapped + trailingSpace
                    }

                    if let link = attributedText.attribute(.link, at: index, effectiveRange: nil) as? URL {
                        formattedText = "[\(formattedText)](\(link.absoluteString))"
                    }
                }

                markdown += formattedText + trailingNewlines
            }
            index = effectiveRange.upperBound
        }

        let indentSteps = paragraphIndentSteps(of: attributedText)
        return markdown
            .components(separatedBy: "\n")
            .enumerated()
            .map { lineIndex, line in
                // Both marker kinds are written with `listMarkerGap` (host-
                // configurable via `toolbarConfiguration.listMarkerSpacing`)
                // in the editor; collapse that back down to a single
                // canonical space here so stored markdown doesn't carry the
                // editor's presentation-only spacing.
                var converted = line.replacingOccurrences(of: "^(\\s*)\(String.bulletGlyphPattern)\\s*", with: "$1- ", options: .regularExpression)
                converted = converted.replacingOccurrences(of: #"^(\s*)(\d+)\.\s*"#, with: "$1$2. ", options: .regularExpression)
                let isListLine = converted.range(of: #"^\s*(-|\d+\.)\s"#, options: .regularExpression) != nil
                if isListLine {
                    let steps = lineIndex < indentSteps.count ? indentSteps[lineIndex] : 0
                    // List lines carry one extra indent step for their base
                    // left indent (see `reflowBlockSpacing`) that isn't part
                    // of the authored nesting level — drop it back out here.
                    let level = max(0, steps - 1)
                    if level > 0 {
                        converted = String(repeating: "    ", count: level) + converted
                    }
                }
                return converted
            }
            .joined(separator: "\n")
    }

    /// Raw indent step count per paragraph (split on "\n"), i.e. `headIndent`
    /// in units of `RichTextEditorViewController.indentStep` — for a list
    /// line this still includes the extra base-indent step `reflowBlockSpacing`
    /// adds, which callers that care about the *authored* nesting level need
    /// to subtract back out themselves.
    private func paragraphIndentSteps(of attributedString: NSAttributedString) -> [Int] {
        let nsString = attributedString.string as NSString
        var steps: [Int] = []
        var location = 0
        while true {
            if location < nsString.length,
               let style = attributedString.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle {
                steps.append(max(0, Int((style.headIndent / Self.indentStep).rounded())))
            } else {
                steps.append(0)
            }
            let remaining = NSRange(location: location, length: nsString.length - location)
            let newlineRange = nsString.range(of: "\n", options: [], range: remaining)
            if newlineRange.location == NSNotFound { break }
            location = newlineRange.location + 1
        }
        return steps
    }
}

// MARK: - Markdown import

extension RichTextEditorViewController {

    /// Inverse of `attributedStringToMarkdown`: builds the attributed string
    /// shown in edit mode from the markdown dialect this editor emits — and
    /// from the wider CommonMark spelling of it other editors produce, since
    /// pasted content isn't written in this editor's own canonical form:
    /// "*"/"+" bullets, "N)" numbers, CRLF line endings, tabs, and nesting
    /// indented by any width (2 spaces, say) rather than exactly 4.
    func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        // The list items enclosing the current line, innermost last, as
        // column positions. A line nests inside the item above it when its
        // marker starts at or past that item's content column — CommonMark's
        // rule, and what makes 2-space (or tabbed, or ragged) indentation
        // read back at the level it was authored at instead of collapsing
        // flat, which is all a plain "count 4-space groups" pass could do.
        var openListItems: [(markerColumn: Int, contentColumn: Int)] = []

        for (index, line) in lines.enumerated() {
            let (indentColumns, afterIndent) = splitLeadingIndent(Substring(line))
            var remainder = afterIndent
            // Anything that isn't a list item still takes its nesting from
            // this editor's own 4-space indent unit.
            var indentLevel = indentColumns / 4

            var headingStyle = HeadingStyle.paragraph
            let hashes = remainder.prefix(while: { $0 == "#" })
            if (1...6).contains(hashes.count), remainder.dropFirst(hashes.count).hasPrefix(" ") {
                headingStyle = [.h1, .h2, .h3, .h4, .h5, .h6][hashes.count - 1]
                remainder = remainder.dropFirst(hashes.count + 1)
            }

            var listMarker: MarkdownListMarker?
            if headingStyle == .paragraph, let marker = splitListMarker(remainder, markerColumn: indentColumns) {
                while let innermost = openListItems.last, indentColumns < innermost.contentColumn {
                    openListItems.removeLast()
                }
                indentLevel = openListItems.count
                openListItems.append((markerColumn: indentColumns, contentColumn: marker.contentColumn))
                listMarker = marker
                remainder = marker.remainder
            } else if headingStyle != .paragraph || !remainder.isEmpty {
                // A heading or an ordinary paragraph ends the list; a blank
                // line doesn't (a loose list keeps going across it).
                openListItems.removeAll()
            }

            let lineFont = headingStyle == .paragraph
                ? baseFont
                : fontMatching(baseFont, pointSize: headingStyle.pointSize(baseFontSize: baseFont.pointSize), forceBold: true)
            let plainAttributes = markdownInlineAttributes(MarkdownInlineStyle(), lineFont: lineFont)
            let isOrderedLine = listMarker?.kind == .ordered
            let isBulletLine = listMarker?.kind == .bullet

            let lineString = NSMutableAttributedString()
            if let listMarker {
                switch listMarker.kind {
                case .bullet:
                    lineString.append(bulletMarkerAttachmentAttributedString(pointSize: lineFont.pointSize, forceBold: false))
                    lineString.append(NSAttributedString(string: listMarkerGap, attributes: plainAttributes))
                case .ordered:
                    // Numbers stay literal text in the editor (only bullets
                    // become an attachment marker), rewritten as "N." plus
                    // `listMarkerGap` so an imported item is spelled exactly
                    // like a typed one — including when the source wrote it
                    // "N)" or with a different gap.
                    lineString.append(NSAttributedString(string: "\(listMarker.number).\(listMarkerGap)", attributes: plainAttributes))
                }
            }
            lineString.append(markdownInlineAttributedString(from: remainder, style: MarkdownInlineStyle(), lineFont: lineFont))
            if index < lines.count - 1 {
                lineString.append(NSAttributedString(string: "\n", attributes: plainAttributes))
            }

            let paragraphStyle = (defaultParagraphStyle().mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            // `reflowBlockSpacing` reverse-derives each list line's nesting
            // level from its stored headIndent by subtracting one step (the
            // base left indent every list line carries) — seed that same
            // step here so a freshly imported list starts from a headIndent
            // reflow will read back correctly, instead of one level shallow.
            let isListLine = isBulletLine || isOrderedLine
            let indent = CGFloat(indentLevel + (isListLine ? 1 : 0)) * Self.indentStep
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            lineString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: lineString.length))
            if headingStyle != .paragraph {
                lineString.addAttribute(.zssHeadingStyle, value: headingStyle.rawValue, range: NSRange(location: 0, length: lineString.length))
            }

            result.append(lineString)
        }

        // The loop above only knows each line's *authored* nesting level (from
        // its leading 4-space groups); it doesn't yet know which lines are
        // list items vs. plain paragraphs/headings, or which pairs of lines
        // continue the same block. Reflow does that classification pass and
        // fixes up spacing/indent so the editor's preview matches how a
        // Markdown renderer (e.g. MarkdownUI) spaces the same content.
        reflowBlockSpacing(in: result)

        return result
    }

    /// Whether `text` carries markdown *block* structure — a heading or a
    /// list item. Pasted text only goes through the markdown importer when it
    /// does, so prose that merely happens to contain a "*" or a "#" is pasted
    /// as the literal text it is.
    func containsMarkdownBlockStructure(_ text: String) -> Bool {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .contains { line in
                let (indentColumns, afterIndent) = splitLeadingIndent(Substring(line))
                if splitListMarker(afterIndent, markerColumn: indentColumns) != nil { return true }
                let hashes = afterIndent.prefix(while: { $0 == "#" })
                return (1...6).contains(hashes.count) && afterIndent.dropFirst(hashes.count).hasPrefix(" ")
            }
    }

    /// Splits the leading indentation off `line`: its width in columns (tabs
    /// expanded to the next four-column stop, how CommonMark counts them) and
    /// the rest of the line.
    private func splitLeadingIndent(_ line: Substring) -> (columns: Int, rest: Substring) {
        var columns = 0
        var rest = line
        while let character = rest.first, character == " " || character == "\t" {
            columns += character == "\t" ? 4 - (columns % 4) : 1
            rest = rest.dropFirst()
        }
        return (columns, rest)
    }

    /// Matches a "- "/"* "/"+ " bullet or a "1. "/"1) " number at the start of
    /// `text` (already stripped of the indentation that starts at
    /// `markerColumn`). The trailing space is required, so a lone "-" line
    /// stays the horizontal rule this editor writes it as and "*emphasis*"
    /// stays emphasis.
    private func splitListMarker(_ text: Substring, markerColumn: Int) -> MarkdownListMarker? {
        let kind: MarkdownListMarker.Kind
        var number = 1
        var rest: Substring

        if let first = text.first, first == "-" || first == "*" || first == "+", text.dropFirst().first == " " {
            kind = .bullet
            rest = text.dropFirst()
        } else {
            let digits = text.prefix(while: { $0.isASCII && $0.isNumber })
            let afterDigits = text.dropFirst(digits.count)
            guard !digits.isEmpty, digits.count <= 9,
                  let delimiter = afterDigits.first, delimiter == "." || delimiter == ")",
                  afterDigits.dropFirst().first == " ",
                  let value = Int(digits)
            else { return nil }
            kind = .ordered
            number = value
            rest = afterDigits.dropFirst()
        }

        let markerWidth = text.count - rest.count
        // CommonMark caps the marker-to-content gap at 4 columns (past that
        // the content is an indented code block, not a deeper hanging
        // indent) — cap it the same way, so a stray run of spaces can't push
        // every following line into a phantom nesting level.
        let gap = min(rest.prefix(while: { $0 == " " }).count, 4)
        return MarkdownListMarker(
            kind: kind,
            contentColumn: markerColumn + markerWidth + gap,
            number: number,
            remainder: rest.dropFirst(gap)
        )
    }

    private func markdownInlineAttributedString(from text: Substring, style: MarkdownInlineStyle, lineFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remainder = text
        var plain = ""
        // Mirrors the live-typing trigger boundary (`activeMentionQueryRange()`'s
        // `(?<!\S)[@#]...`): a token only starts at the beginning of this span or
        // right after whitespace, so "john@example.com" doesn't get mistaken for
        // a mention. Defaults true at the start of every call (including nested
        // calls for link labels/emphasis content), treating the start of a
        // bracket/delimiter span as a boundary too.
        var precededByWhitespace = true

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
                precededByWhitespace = false
                continue
            }

            if precededByWhitespace, let match = matchMentionToken(remainder) {
                flushPlain()
                result.append(mentionOrHashtagPillAttributedString(trigger: match.trigger, token: String(match.token), style: style, lineFont: lineFont))
                remainder = match.remainder
                precededByWhitespace = false
                continue
            }

            if let span = matchMarkdownDelimiter(remainder) {
                flushPlain()
                var innerStyle = style
                span.apply(&innerStyle)
                result.append(markdownInlineAttributedString(from: span.content, style: innerStyle, lineFont: lineFont))
                remainder = span.remainder
                precededByWhitespace = false
                continue
            }

            let char = remainder.removeFirst()
            plain.append(char)
            precededByWhitespace = char.isWhitespace
        }

        flushPlain()
        return result
    }

    /// Matches an "@identifier" or "#tag" token at the start of `text` — the
    /// inverse of what `attributedStringToMarkdown` emits for a mention/hashtag
    /// pill. Character class matches `activeMentionQueryRange()`'s
    /// `[A-Za-z0-9_]*` exactly, so import recognizes precisely the tokens the
    /// live suggestion picker could have produced.
    private func matchMentionToken(_ text: Substring) -> (trigger: MentionTrigger, token: Substring, remainder: Substring)? {
        guard let first = text.first, let trigger = MentionTrigger(rawValue: first) else { return nil }
        let rest = text.dropFirst()
        let token = rest.prefix { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
        guard !token.isEmpty else { return nil }
        return (trigger, token, rest.dropFirst(token.count))
    }

    /// Builds a mention/hashtag pill directly from the parsed token text, the
    /// same way picking a suggestion from the live "@"/"#" picker does — no
    /// backend lookup: the token text itself becomes the pill's identifier
    /// and display name, via the same `MentionSuggestion`/`HashtagSuggestion`
    /// value types and `mentionPillAttachment`/`hashtagPillAttachment`
    /// rendering `insertMention(_:)` uses, so an imported pill is visually
    /// identical to a typed-and-picked one.
    private func mentionOrHashtagPillAttributedString(trigger: MentionTrigger, token: String, style: MarkdownInlineStyle, lineFont: UIFont) -> NSAttributedString {
        let entry: MentionSuggestionEntry
        let attachment: NSTextAttachment
        switch trigger {
        case .at:
            let item = MentionSuggestion(displayName: token)
            attachment = mentionPillAttachment(for: item)
            entry = .mention(item)
        case .hash:
            let item = HashtagSuggestion(name: token)
            attachment = hashtagPillAttachment(for: item)
            entry = .hashtag(item)
        }

        let result = NSMutableAttributedString(attachment: attachment)
        let range = NSRange(location: 0, length: result.length)
        var attributes = markdownInlineAttributes(style, lineFont: lineFont)
        attributes.removeValue(forKey: .backgroundColor)
        result.addAttributes(attributes, range: range)
        switch entry {
        case .mention(let item): result.addAttribute(.zssMentionItem, value: item, range: range)
        case .hashtag(let item): result.addAttribute(.zssHashtagItem, value: item, range: range)
        }
        result.addAttribute(.zssMentionTrigger, value: trigger.symbol, range: range)
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
