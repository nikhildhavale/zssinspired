import UIKit

public final class RichTextEditorViewController: UIViewController {

    fileprivate enum EditorMode {
        case richText
        case html
    }

    fileprivate enum ListMode {
        case none
        case unordered
        case ordered
    }

    fileprivate enum HeadingStyle: String, CaseIterable, Hashable {
        case paragraph = "P"
        case h1 = "H1"
        case h2 = "H2"
        case h3 = "H3"
        case h4 = "H4"
        case h5 = "H5"
        case h6 = "H6"

        var pointSize: CGFloat {
            switch self {
            case .paragraph: return 17
            case .h1: return 34
            case .h2: return 28
            case .h3: return 24
            case .h4: return 21
            case .h5: return 19
            case .h6: return 17
            }
        }

        var isBold: Bool {
            self != .paragraph
        }
    }

    fileprivate enum ToolbarItem: Hashable {
        case bold
        case italic
        case underline
        case strikeThrough
        case subscriptStyle
        case superscriptStyle
        case heading(HeadingStyle)
        case alignLeft
        case alignCenter
        case alignRight
        case alignJustified
        case unorderedList
        case orderedList
        case link
        case foregroundColor
        case backgroundColor
    }

    private let editorTextView = UITextView()
    private let htmlTextView = UITextView()
    private let toolbarScrollView = UIScrollView()
    private let toolbarStackView = UIStackView()
    private let modeControl = UISegmentedControl(items: ["Edit", "HTML"])
    private let placeholderLabel = UILabel()

    private var editorMode: EditorMode = .richText
    private var listMode: ListMode = .none
    private var orderedListCounter = 1
    private var selectedHeadingStyle: HeadingStyle = .paragraph
    private var isSyncingText = false
    private var toolbarButtons: [ToolbarItem: UIButton] = [:]

    private let baseFont = UIFont.preferredFont(forTextStyle: .body)
    private let linkColor = UIColor.systemBlue

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureToolbar()
        configureTextViews()
        setInitialContent()
    }
}

private extension RichTextEditorViewController {

    func configureView() {
        title = "ZSS Inspired Editor"
        view.backgroundColor = .systemBackground

        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.showsHorizontalScrollIndicator = false
        toolbarScrollView.backgroundColor = .secondarySystemBackground

        toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarStackView.axis = .horizontal
        toolbarStackView.alignment = .center
        toolbarStackView.spacing = 8
        toolbarStackView.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        toolbarStackView.isLayoutMarginsRelativeArrangement = true

        editorTextView.translatesAutoresizingMaskIntoConstraints = false
        htmlTextView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbarScrollView)
        toolbarScrollView.addSubview(toolbarStackView)
        view.addSubview(editorTextView)
        view.addSubview(htmlTextView)

        NSLayoutConstraint.activate([
            toolbarScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarScrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            toolbarScrollView.heightAnchor.constraint(equalToConstant: 58),

            toolbarStackView.topAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.topAnchor),
            toolbarStackView.leadingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.leadingAnchor),
            toolbarStackView.trailingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.trailingAnchor),
            toolbarStackView.bottomAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.bottomAnchor),
            toolbarStackView.heightAnchor.constraint(equalTo: toolbarScrollView.frameLayoutGuide.heightAnchor),

            editorTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editorTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorTextView.bottomAnchor.constraint(equalTo: toolbarScrollView.topAnchor),

            htmlTextView.topAnchor.constraint(equalTo: editorTextView.topAnchor),
            htmlTextView.leadingAnchor.constraint(equalTo: editorTextView.leadingAnchor),
            htmlTextView.trailingAnchor.constraint(equalTo: editorTextView.trailingAnchor),
            htmlTextView.bottomAnchor.constraint(equalTo: editorTextView.bottomAnchor)
        ])
    }

    func configureToolbar() {
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        toolbarStackView.addArrangedSubview(modeControl)
        toolbarStackView.addArrangedSubview(separator())

        addToolbarButton(.bold, title: "B", imageName: "bold", action: #selector(toggleBold))
        addToolbarButton(.italic, title: "I", imageName: "italic", action: #selector(toggleItalic))
        addToolbarButton(.underline, title: "U", imageName: "underline", action: #selector(toggleUnderlineStyle))
        addToolbarButton(.strikeThrough, title: "S", imageName: "strikethrough", action: #selector(toggleStrikeThroughStyle))
        addToolbarButton(.subscriptStyle, title: "x2", imageName: "textformat.subscript", action: #selector(toggleSubscript))
        addToolbarButton(.superscriptStyle, title: "x2", imageName: "textformat.superscript", action: #selector(toggleSuperscript))
        addToolbarButton(title: "Tx", imageName: "clear", action: #selector(removeFormatting))
        toolbarStackView.addArrangedSubview(separator())

        for style in HeadingStyle.allCases {
            addToolbarButton(.heading(style), title: style.rawValue, imageName: nil, action: #selector(applyHeadingStyle(_:)), accessibilityValue: style.rawValue)
        }
        toolbarStackView.addArrangedSubview(separator())

        addToolbarButton(.alignLeft, title: "L", imageName: "text.alignleft", action: #selector(alignLeft))
        addToolbarButton(.alignCenter, title: "C", imageName: "text.aligncenter", action: #selector(alignCenter))
        addToolbarButton(.alignRight, title: "R", imageName: "text.alignright", action: #selector(alignRight))
        addToolbarButton(.alignJustified, title: "J", imageName: "text.justify", action: #selector(alignJustified))
        toolbarStackView.addArrangedSubview(separator())

        addToolbarButton(.unorderedList, title: "•", imageName: "list.bullet", action: #selector(toggleUnorderedList))
        addToolbarButton(.orderedList, title: "1.", imageName: "list.number", action: #selector(toggleOrderedList))
        addToolbarButton(title: "<", imageName: "decrease.indent", action: #selector(outdentSelection))
        addToolbarButton(title: ">", imageName: "increase.indent", action: #selector(indentSelection))
        toolbarStackView.addArrangedSubview(separator())

        addToolbarButton(title: "↶", imageName: "arrow.uturn.backward", action: #selector(undo))
        addToolbarButton(title: "↷", imageName: "arrow.uturn.forward", action: #selector(redo))
        addToolbarButton(.link, title: "🔗", imageName: "link", action: #selector(insertLink))
        addToolbarButton(title: "⊘", imageName: "link.badge.minus", action: #selector(removeLink))
        addToolbarButton(title: "Img", imageName: "photo", action: #selector(insertImagePlaceholder))
        addToolbarButton(title: "—", imageName: "minus", action: #selector(insertHorizontalRule))
        addToolbarButton(.foregroundColor, title: "A", imageName: "paintpalette", action: #selector(applyForegroundColor))
        addToolbarButton(.backgroundColor, title: "Bg", imageName: "highlighter", action: #selector(applyBackgroundColor))
    }

    func configureTextViews() {
        editorTextView.delegate = self
        editorTextView.allowsEditingTextAttributes = true
        editorTextView.font = baseFont
        editorTextView.adjustsFontForContentSizeCategory = true
        editorTextView.backgroundColor = .systemBackground
        editorTextView.keyboardDismissMode = .interactive
        editorTextView.textContainerInset = UIEdgeInsets(top: 22, left: 18, bottom: 22, right: 18)
        editorTextView.typingAttributes = defaultTypingAttributes()

        placeholderLabel.text = "Start writing..."
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = baseFont
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        editorTextView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: editorTextView.topAnchor, constant: 27),
            placeholderLabel.leadingAnchor.constraint(equalTo: editorTextView.leadingAnchor, constant: 23)
        ])

        htmlTextView.delegate = self
        htmlTextView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        htmlTextView.backgroundColor = .systemGroupedBackground
        htmlTextView.textContainerInset = editorTextView.textContainerInset
        htmlTextView.autocorrectionType = .no
        htmlTextView.autocapitalizationType = .none
        htmlTextView.isHidden = true
    }

    func setInitialContent() {
        editorTextView.attributedText = NSAttributedString(
            string: "",
            attributes: defaultTypingAttributes()
        )
        updatePlaceholder()
        updateToolbarSelectionState()
    }

    private func addToolbarButton(_ item: ToolbarItem? = nil, title: String, imageName: String?, action: Selector, accessibilityValue: String? = nil) {
        var configuration = UIButton.Configuration.bordered()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        if let imageName, let image = UIImage(systemName: imageName) {
            configuration.image = image
        } else {
            configuration.title = title
        }

        let button = UIButton(configuration: configuration)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.accessibilityLabel = title
        button.accessibilityValue = accessibilityValue
        button.configurationUpdateHandler = { button in
            var updatedConfiguration = button.configuration ?? .bordered()
            updatedConfiguration.baseForegroundColor = button.isSelected ? .white : .label
            updatedConfiguration.baseBackgroundColor = button.isSelected ? .systemBlue : .clear
            button.configuration = updatedConfiguration
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        toolbarStackView.addArrangedSubview(button)

        if let item {
            toolbarButtons[item] = button
        }
    }

    func separator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return view
    }
}

private extension RichTextEditorViewController {

    @objc func modeChanged() {
        if modeControl.selectedSegmentIndex == 0 {
            syncHTMLToEditor()
            setMode(.richText)
        } else {
            htmlTextView.text = htmlString()
            setMode(.html)
        }
    }

    private func setMode(_ mode: EditorMode) {
        editorMode = mode
        editorTextView.isHidden = mode != .richText
        htmlTextView.isHidden = mode != .html
        if mode == .richText {
            editorTextView.becomeFirstResponder()
        } else {
            htmlTextView.becomeFirstResponder()
        }
    }

    @objc func toggleBold() {
        toggleFontTrait(.traitBold)
    }

    @objc func toggleItalic() {
        toggleFontTrait(.traitItalic)
    }

    @objc func toggleUnderlineStyle() {
        toggleAttribute(.underlineStyle, enabledValue: NSUnderlineStyle.single.rawValue)
    }

    @objc func toggleStrikeThroughStyle() {
        toggleAttribute(.strikethroughStyle, enabledValue: NSUnderlineStyle.single.rawValue)
    }

    @objc func toggleSubscript() {
        toggleExclusiveBaseline(offset: -5)
    }

    @objc func toggleSuperscript() {
        toggleExclusiveBaseline(offset: 5)
    }

    @objc func removeFormatting() {
        let range = editorTextView.selectedRange
        guard range.length > 0 else {
            editorTextView.typingAttributes = defaultTypingAttributes()
            updateToolbarSelectionState()
            return
        }

        let plainText = (editorTextView.text as NSString).substring(with: range)
        let replacement = NSAttributedString(string: plainText, attributes: defaultTypingAttributes())
        replaceSelection(with: replacement, selectedOffset: replacement.length)
    }

    @objc func applyHeadingStyle(_ sender: UIButton) {
        guard
            let rawValue = sender.accessibilityValue,
            let headingStyle = HeadingStyle(rawValue: rawValue)
        else { return }

        selectedHeadingStyle = headingStyle
        let range = currentParagraphRange()
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let existingFont = (value as? UIFont) ?? baseFont
            let font = fontMatching(existingFont, pointSize: headingStyle.pointSize, forceBold: headingStyle.isBold)
            mutableText.addAttribute(.font, value: font, range: subrange)
        }
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: range.upperBound, length: 0)
        editorTextView.typingAttributes[.font] = fontMatching(currentFont(), pointSize: headingStyle.pointSize, forceBold: headingStyle.isBold)
        updateToolbarSelectionState()
    }

    @objc func alignLeft() {
        applyAlignment(.left)
    }

    @objc func alignCenter() {
        applyAlignment(.center)
    }

    @objc func alignRight() {
        applyAlignment(.right)
    }

    @objc func alignJustified() {
        applyAlignment(.justified)
    }

    @objc func toggleUnorderedList() {
        if listMode == .unordered {
            listMode = .none
            removeListMarkersFromCurrentParagraphs()
        } else {
            listMode = .unordered
            orderedListCounter = 1
            applyListMarkersToCurrentParagraphs()
        }
    }

    @objc func toggleOrderedList() {
        if listMode == .ordered {
            listMode = .none
            removeListMarkersFromCurrentParagraphs()
        } else {
            listMode = .ordered
            orderedListCounter = nextOrderedListNumber()
            applyListMarkersToCurrentParagraphs()
        }
    }

    @objc func indentSelection() {
        updateParagraphStyle { style in
            style.firstLineHeadIndent += 24
            style.headIndent += 24
        }
    }

    @objc func outdentSelection() {
        updateParagraphStyle { style in
            style.firstLineHeadIndent = max(0, style.firstLineHeadIndent - 24)
            style.headIndent = max(0, style.headIndent - 24)
        }
    }

    @objc func undo() {
        editorTextView.undoManager?.undo()
    }

    @objc func redo() {
        editorTextView.undoManager?.redo()
    }

    @objc func insertLink() {
        let selectedText = selectedPlainText()
        let title = selectedText.isEmpty ? "OpenAI" : selectedText
        let url = URL(string: "https://openai.com")!
        let attributes = linkTypingAttributes(url: url)
        replaceSelection(with: NSAttributedString(string: title, attributes: attributes), selectedOffset: title.count)
    }

    @objc func removeLink() {
        let range = effectiveSelectionOrCurrentWordRange()
        guard range.length > 0 else { return }
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.removeAttribute(.link, range: range)
        mutableText.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        mutableText.removeAttribute(.underlineStyle, range: range)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = range
        updateToolbarSelectionState()
    }

    @objc func insertImagePlaceholder() {
        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        attachment.image = UIImage(systemName: "photo", withConfiguration: config)?.withTintColor(.secondaryLabel)
        attachment.bounds = CGRect(x: 0, y: -12, width: 64, height: 48)

        let imageText = NSMutableAttributedString(attachment: attachment)
        imageText.append(NSAttributedString(string: "\n", attributes: defaultTypingAttributes()))
        replaceSelection(with: imageText, selectedOffset: imageText.length)
    }

    @objc func insertHorizontalRule() {
        replaceSelection(with: NSAttributedString(string: "\n────────────\n", attributes: defaultTypingAttributes()), selectedOffset: 14)
    }

    @objc func applyForegroundColor() {
        toggleAttribute(.foregroundColor, enabledValue: UIColor.systemRed)
    }

    @objc func applyBackgroundColor() {
        toggleAttribute(.backgroundColor, enabledValue: UIColor.systemYellow.withAlphaComponent(0.45))
    }
}

private extension RichTextEditorViewController {

    func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle()
        ]
    }

    func defaultParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacing = 8
        return style
    }

    func currentFont() -> UIFont {
        if let font = editorTextView.typingAttributes[.font] as? UIFont {
            return font
        }

        let location = max(0, editorTextView.selectedRange.location - 1)
        guard editorTextView.attributedText.length > location else {
            return baseFont
        }

        return editorTextView.attributedText.attribute(.font, at: location, effectiveRange: nil) as? UIFont ?? baseFont
    }

    func fontMatching(_ font: UIFont, pointSize: CGFloat? = nil, forceBold: Bool? = nil) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if let forceBold {
            if forceBold {
                traits.insert(.traitBold)
            } else {
                traits.remove(.traitBold)
            }
        }

        let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize ?? font.pointSize)
    }

    func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        let range = editorTextView.selectedRange
        let current = currentFont()
        var traits = current.fontDescriptor.symbolicTraits

        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }

        let descriptor = current.fontDescriptor.withSymbolicTraits(traits) ?? current.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: current.pointSize)
        applyAttribute(.font, value: font, range: range)
    }

    func toggleAttribute(_ key: NSAttributedString.Key, enabledValue: Any) {
        let range = editorTextView.selectedRange
        let location = max(0, min(editorTextView.attributedText.length - 1, range.location))
        let existingValue = editorTextView.attributedText.length > 0 ? editorTextView.attributedText.attribute(key, at: location, effectiveRange: nil) : nil

        if existingValue == nil {
            applyAttribute(key, value: enabledValue, range: range)
        } else {
            removeAttribute(key, range: range)
        }
    }

    func toggleExclusiveBaseline(offset: Int) {
        let range = editorTextView.selectedRange
        let key = NSAttributedString.Key.baselineOffset
        let location = max(0, min(editorTextView.attributedText.length - 1, range.location))
        let currentOffset = editorTextView.attributedText.length > 0 ? editorTextView.attributedText.attribute(key, at: location, effectiveRange: nil) as? Int : nil

        if currentOffset == offset {
            removeAttribute(key, range: range)
        } else {
            applyAttribute(key, value: offset, range: range)
        }
    }

    func applyAttribute(_ key: NSAttributedString.Key, value: Any, range: NSRange) {
        if range.length == 0 {
            editorTextView.typingAttributes[key] = value
            updateToolbarSelectionState()
            return
        }

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.addAttribute(key, value: value, range: range)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = range
        updateToolbarSelectionState()
    }

    func removeAttribute(_ key: NSAttributedString.Key, range: NSRange) {
        if range.length == 0 {
            editorTextView.typingAttributes.removeValue(forKey: key)
            updateToolbarSelectionState()
            return
        }

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.removeAttribute(key, range: range)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = range
        updateToolbarSelectionState()
    }

    func replaceSelection(with attributedString: NSAttributedString, selectedOffset: Int) {
        let range = editorTextView.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.replaceCharacters(in: range, with: attributedString)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: range.location + selectedOffset, length: 0)
        updatePlaceholder()
        updateToolbarSelectionState()
    }

    func applyAlignment(_ alignment: NSTextAlignment) {
        updateParagraphStyle { style in
            style.alignment = alignment
        }
    }

    func updateParagraphStyle(_ transform: (NSMutableParagraphStyle) -> Void) {
        let range = currentParagraphRange()
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            transform(style)
            mutableText.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = range
        editorTextView.typingAttributes[.paragraphStyle] = (mutableText.attribute(.paragraphStyle, at: max(0, range.location), effectiveRange: nil) as? NSParagraphStyle) ?? defaultParagraphStyle()
        updateToolbarSelectionState()
    }

    func currentParagraphRange() -> NSRange {
        let text = editorTextView.text as NSString? ?? ""
        guard text.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let selection = editorTextView.selectedRange
        let location = min(selection.location, text.length - 1)
        var range = text.paragraphRange(for: NSRange(location: location, length: max(selection.length, 1)))
        if range.upperBound > editorTextView.attributedText.length {
            range.length = editorTextView.attributedText.length - range.location
        }
        return range
    }

    func selectedPlainText() -> String {
        let range = editorTextView.selectedRange
        guard range.length > 0 else { return "" }
        return (editorTextView.text as NSString).substring(with: range)
    }

    func effectiveSelectionOrCurrentWordRange() -> NSRange {
        let selection = editorTextView.selectedRange
        if selection.length > 0 {
            return selection
        }

        let text = editorTextView.text as NSString
        guard text.length > 0, selection.location <= text.length else {
            return selection
        }

        let characterSet = CharacterSet.whitespacesAndNewlines
        var start = selection.location
        var end = selection.location

        while start > 0 {
            let previous = text.substring(with: NSRange(location: start - 1, length: 1))
            if previous.rangeOfCharacter(from: characterSet) != nil { break }
            start -= 1
        }

        while end < text.length {
            let next = text.substring(with: NSRange(location: end, length: 1))
            if next.rangeOfCharacter(from: characterSet) != nil { break }
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    func updateToolbarSelectionState() {
        guard editorMode == .richText else { return }

        setToolbarButton(.bold, selected: selectionHasFontTrait(.traitBold))
        setToolbarButton(.italic, selected: selectionHasFontTrait(.traitItalic))
        setToolbarButton(.underline, selected: selectionHasAttribute(.underlineStyle))
        setToolbarButton(.strikeThrough, selected: selectionHasAttribute(.strikethroughStyle))
        setToolbarButton(.subscriptStyle, selected: selectionHasBaselineOffset { $0 < 0 })
        setToolbarButton(.superscriptStyle, selected: selectionHasBaselineOffset { $0 > 0 })
        setToolbarButton(.link, selected: selectionHasAttribute(.link))
        setToolbarButton(.foregroundColor, selected: selectionHasNonDefaultColor(.foregroundColor, defaultColor: .label))
        setToolbarButton(.backgroundColor, selected: selectionHasAttribute(.backgroundColor))

        let headingStyle = currentHeadingStyle()
        for style in HeadingStyle.allCases {
            setToolbarButton(.heading(style), selected: style == headingStyle)
        }

        switch currentParagraphAlignment() {
        case .center:
            setAlignmentButtons(selected: .alignCenter)
        case .right:
            setAlignmentButtons(selected: .alignRight)
        case .justified:
            setAlignmentButtons(selected: .alignJustified)
        default:
            setAlignmentButtons(selected: .alignLeft)
        }

        switch currentListMode() {
        case .unordered:
            setToolbarButton(.unorderedList, selected: true)
            setToolbarButton(.orderedList, selected: false)
        case .ordered:
            setToolbarButton(.unorderedList, selected: false)
            setToolbarButton(.orderedList, selected: true)
        case .none:
            setToolbarButton(.unorderedList, selected: false)
            setToolbarButton(.orderedList, selected: false)
        }
    }

    private func setToolbarButton(_ item: ToolbarItem, selected: Bool) {
        guard let button = toolbarButtons[item], button.isSelected != selected else { return }
        button.isSelected = selected
    }

    private func setAlignmentButtons(selected selectedItem: ToolbarItem) {
        for item in [ToolbarItem.alignLeft, .alignCenter, .alignRight, .alignJustified] {
            setToolbarButton(item, selected: item == selectedItem)
        }
    }

    func selectionInspectionRange() -> NSRange? {
        let textLength = editorTextView.attributedText.length
        guard textLength > 0 else { return nil }

        let selection = editorTextView.selectedRange
        if selection.length > 0 {
            return NSRange(location: selection.location, length: min(selection.length, textLength - selection.location))
        }

        let location = selection.location == textLength ? max(0, textLength - 1) : min(selection.location, textLength - 1)
        return NSRange(location: location, length: 1)
    }

    func selectionHasFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        guard let range = selectionInspectionRange() else {
            return (editorTextView.typingAttributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(trait) == true
        }

        var hasText = false
        var allTextHasTrait = true
        editorTextView.attributedText.enumerateAttribute(.font, in: range) { value, subrange, stop in
            guard subrange.length > 0 else { return }
            hasText = true
            let font = (value as? UIFont) ?? baseFont
            if !font.fontDescriptor.symbolicTraits.contains(trait) {
                allTextHasTrait = false
                stop.pointee = true
            }
        }
        return hasText && allTextHasTrait
    }

    func selectionHasAttribute(_ key: NSAttributedString.Key) -> Bool {
        guard let range = selectionInspectionRange() else {
            return editorTextView.typingAttributes[key] != nil
        }

        var hasText = false
        var allTextHasAttribute = true
        editorTextView.attributedText.enumerateAttribute(key, in: range) { value, subrange, stop in
            guard subrange.length > 0 else { return }
            hasText = true
            if value == nil {
                allTextHasAttribute = false
                stop.pointee = true
            }
        }
        return hasText && allTextHasAttribute
    }

    func selectionHasBaselineOffset(_ predicate: (Double) -> Bool) -> Bool {
        guard let range = selectionInspectionRange() else {
            return numericValue(editorTextView.typingAttributes[.baselineOffset]).map(predicate) == true
        }

        var hasText = false
        var allTextMatches = true
        editorTextView.attributedText.enumerateAttribute(.baselineOffset, in: range) { value, subrange, stop in
            guard subrange.length > 0 else { return }
            hasText = true
            guard let offset = numericValue(value), predicate(offset) else {
                allTextMatches = false
                stop.pointee = true
                return
            }
        }
        return hasText && allTextMatches
    }

    func selectionHasNonDefaultColor(_ key: NSAttributedString.Key, defaultColor: UIColor) -> Bool {
        guard let range = selectionInspectionRange() else {
            guard let color = editorTextView.typingAttributes[key] as? UIColor else { return false }
            return !color.isEqual(defaultColor)
        }

        var hasCustomColor = false
        editorTextView.attributedText.enumerateAttribute(key, in: range) { value, _, stop in
            guard let color = value as? UIColor, !color.isEqual(defaultColor) else { return }
            hasCustomColor = true
            stop.pointee = true
        }
        return hasCustomColor
    }

    private func currentHeadingStyle() -> HeadingStyle {
        let font = inspectedFont()
        return HeadingStyle.allCases.min { lhs, rhs in
            abs(lhs.pointSize - font.pointSize) < abs(rhs.pointSize - font.pointSize)
        } ?? .paragraph
    }

    func inspectedFont() -> UIFont {
        guard let range = selectionInspectionRange() else {
            return editorTextView.typingAttributes[.font] as? UIFont ?? baseFont
        }

        return editorTextView.attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? baseFont
    }

    func currentParagraphAlignment() -> NSTextAlignment {
        let paragraphRange = currentParagraphRange()
        guard editorTextView.attributedText.length > 0, paragraphRange.location < editorTextView.attributedText.length else {
            return (editorTextView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .left
        }

        let style = editorTextView.attributedText.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
        return style?.alignment ?? .left
    }

    private func currentListMode() -> ListMode {
        let paragraphRange = currentParagraphRange()
        guard editorTextView.text.count > 0, paragraphRange.location < (editorTextView.text as NSString).length else {
            return listMode
        }

        let paragraph = (editorTextView.text as NSString).substring(with: paragraphRange)
        if paragraph.trimmingCharacters(in: .whitespaces).hasPrefix("•") {
            return .unordered
        }
        if paragraph.orderedListNumber != nil {
            return .ordered
        }
        return .none
    }

    func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Int:
            return Double(value)
        case let value as CGFloat:
            return Double(value)
        case let value as Double:
            return value
        case let value as NSNumber:
            return value.doubleValue
        default:
            return nil
        }
    }
}

private extension RichTextEditorViewController {

    func applyListMarkersToCurrentParagraphs() {
        let range = currentParagraphRange()
        let nsText = editorTextView.text as NSString
        if nsText.length == 0 {
            let marker = listMode == .ordered ? "\(orderedListCounter). " : "• "
            orderedListCounter += listMode == .ordered ? 1 : 0
            replaceSelection(with: NSAttributedString(string: marker, attributes: editorTextView.typingAttributes), selectedOffset: marker.count)
            return
        }

        let paragraphRanges = paragraphRanges(in: range, textLength: nsText.length)
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        var locationDelta = 0
        var currentNumber = orderedListCounter

        for paragraphRange in paragraphRanges {
            let adjustedLocation = paragraphRange.location + locationDelta
            let adjustedRange = NSRange(location: adjustedLocation, length: paragraphRange.length)
            let paragraph = (mutableText.string as NSString).substring(with: adjustedRange)

            if paragraph.hasListMarker {
                continue
            }

            let marker: String
            switch listMode {
            case .unordered:
                marker = "• "
            case .ordered:
                marker = "\(currentNumber). "
                currentNumber += 1
            case .none:
                return
            }

            mutableText.insert(NSAttributedString(string: marker, attributes: editorTextView.typingAttributes), at: adjustedLocation)
            locationDelta += marker.count
        }

        orderedListCounter = currentNumber
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: range.location + locationDelta, length: 0)
        updatePlaceholder()
        updateToolbarSelectionState()
    }

    func removeListMarkersFromCurrentParagraphs() {
        let range = currentParagraphRange()
        let paragraphRanges = paragraphRanges(in: range, textLength: editorTextView.text.count)
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        var locationDelta = 0

        for paragraphRange in paragraphRanges {
            let adjustedLocation = paragraphRange.location - locationDelta
            guard adjustedLocation < mutableText.length else { continue }

            let adjustedRange = NSRange(location: adjustedLocation, length: min(paragraphRange.length, mutableText.length - adjustedLocation))
            let paragraph = (mutableText.string as NSString).substring(with: adjustedRange)
            guard let markerRange = paragraph.listMarkerRange else { continue }

            mutableText.deleteCharacters(in: NSRange(location: adjustedLocation, length: markerRange.length))
            locationDelta += markerRange.length
        }

        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: max(0, range.location - locationDelta), length: 0)
        updatePlaceholder()
        updateToolbarSelectionState()
    }

    func paragraphRanges(in range: NSRange, textLength: Int) -> [NSRange] {
        let text = editorTextView.text as NSString
        guard textLength > 0 else { return [] }

        var ranges: [NSRange] = []
        var cursor = range.location
        let upperBound = min(range.upperBound, textLength)

        while cursor < upperBound {
            let paragraphRange = text.paragraphRange(for: NSRange(location: cursor, length: 0))
            ranges.append(paragraphRange)
            cursor = paragraphRange.upperBound
        }

        if ranges.isEmpty {
            ranges.append(text.paragraphRange(for: NSRange(location: min(range.location, textLength - 1), length: 0)))
        }

        return ranges
    }

    func nextOrderedListNumber() -> Int {
        let text = editorTextView.text as NSString? ?? ""
        let location = max(0, min(editorTextView.selectedRange.location, text.length))
        let prefix = text.substring(to: location)
        let numbers = prefix
            .components(separatedBy: .newlines)
            .compactMap { $0.orderedListNumber }
        return (numbers.last ?? 0) + 1
    }

    func continuationMarker(afterPreviousLine previousLine: String) -> String? {
        switch listMode {
        case .none:
            if previousLine.trimmingCharacters(in: .whitespaces).hasPrefix("•") {
                return "• "
            }
            if let number = previousLine.orderedListNumber {
                return "\(number + 1). "
            }
            return nil
        case .unordered:
            return "• "
        case .ordered:
            let nextNumber = previousLine.orderedListNumber.map { $0 + 1 } ?? orderedListCounter
            orderedListCounter = nextNumber + 1
            return "\(nextNumber). "
        }
    }

    func shouldEndList(afterPreviousLine previousLine: String) -> Bool {
        let trimmed = previousLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "•" || trimmed.range(of: #"^\d+\.$"#, options: .regularExpression) != nil
    }

    func removePreviousEmptyListMarker() -> Bool {
        let text = editorTextView.text as NSString
        let selection = editorTextView.selectedRange
        guard selection.location > 0 else { return false }

        let previousParagraph = text.paragraphRange(for: NSRange(location: selection.location - 1, length: 0))
        let previousLine = text.substring(with: previousParagraph)
        guard shouldEndList(afterPreviousLine: previousLine), let markerRange = previousLine.listMarkerRange else {
            return false
        }

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.deleteCharacters(in: NSRange(location: previousParagraph.location, length: markerRange.length))
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: previousParagraph.location, length: 0)
        listMode = .none
        updatePlaceholder()
        updateToolbarSelectionState()
        return true
    }

    func isEmptyParagraph(_ paragraph: String) -> Bool {
        paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension RichTextEditorViewController {

    func htmlString() -> String {
        let range = NSRange(location: 0, length: editorTextView.attributedText.length)
        guard
            let data = try? editorTextView.attributedText.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            ),
            let html = String(data: data, encoding: .utf8)
        else {
            return editorTextView.text
        }

        return html
    }

    func syncHTMLToEditor() {
        guard let data = htmlTextView.text.data(using: .utf8) else { return }
        let attributedText = try? NSMutableAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )

        editorTextView.attributedText = attributedText ?? NSAttributedString(string: htmlTextView.text, attributes: defaultTypingAttributes())
        editorTextView.typingAttributes = defaultTypingAttributes()
        updatePlaceholder()
    }

    func linkTypingAttributes(url: URL) -> [NSAttributedString.Key: Any] {
        var attributes = defaultTypingAttributes()
        attributes[.link] = url
        attributes[.foregroundColor] = linkColor
        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        return attributes
    }

    func updatePlaceholder() {
        placeholderLabel.isHidden = !editorTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension RichTextEditorViewController: UITextViewDelegate {

    public func textViewDidChange(_ textView: UITextView) {
        guard !isSyncingText else { return }
        if textView == editorTextView {
            updatePlaceholder()
            updateToolbarSelectionState()
        }
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView == editorTextView, !isSyncingText else { return }
        updateToolbarSelectionState()
    }

    public func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard textView == editorTextView, text == "\n" else {
            return true
        }

        if removePreviousEmptyListMarker() {
            return false
        }

        let nsText = editorTextView.text as NSString
        let previousParagraphRange = nsText.paragraphRange(for: NSRange(location: max(0, range.location - 1), length: 0))
        let previousLine = nsText.substring(with: previousParagraphRange)

        guard let marker = continuationMarker(afterPreviousLine: previousLine) else {
            return true
        }

        let insertion = NSAttributedString(string: "\n\(marker)", attributes: editorTextView.typingAttributes)
        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.replaceCharacters(in: range, with: insertion)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
        updatePlaceholder()
        updateToolbarSelectionState()
        return false
    }
}

private extension String {

    var hasListMarker: Bool {
        listMarkerRange != nil
    }

    var listMarkerRange: NSRange? {
        let nsString = self as NSString
        if range(of: #"^\s*•\s"#, options: .regularExpression) != nil {
            return nsString.range(of: #"^\s*•\s"#, options: .regularExpression)
        }

        let orderedRange = nsString.range(of: #"^\s*\d+\.\s"#, options: .regularExpression)
        return orderedRange.location == NSNotFound ? nil : orderedRange
    }

    var orderedListNumber: Int? {
        let nsString = self as NSString
        let range = nsString.range(of: #"^\s*(\d+)\.\s"#, options: .regularExpression)
        guard range.location != NSNotFound else { return nil }

        let marker = nsString.substring(with: range)
        return Int(marker.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ""))
    }
}
