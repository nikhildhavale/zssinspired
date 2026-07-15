import UIKit

public final class RichTextEditorViewController: UIViewController {

    public var mentionConfiguration: MentionConfiguration {
        didSet {
            guard isViewLoaded else { return }
            applyMentionConfiguration()
            updateMentionSuggestions()
        }
    }

    public var toolbarConfiguration: ToolbarConfiguration {
        didSet {
            guard isViewLoaded else { return }
            toolbarHeightConstraint?.constant = toolbarConfiguration.toolbarHeight
            configureToolbar()
            if oldValue.contentMode != toolbarConfiguration.contentMode {
                updateToolbarSelectionState()
            }
        }
    }

    public var contentMode: ContentMode {
        toolbarConfiguration.contentMode
    }

    public func setContentMode(_ mode: ContentMode) {
        // The toolbarConfiguration didSet rebuilds the toolbar for the new mode.
        toolbarConfiguration.contentMode = mode
    }

    public var onMentionQueryChanged: ((String?) -> Void)?
    public var onMentionInserted: ((any MentionItem) -> Void)?
    public var onMentionRemoved: ((any MentionItem) -> Void)?
    public private(set) var insertedMentions: [any MentionItem] = []
    public var onHashtagInserted: ((any HashtagItem) -> Void)?
    public var onHashtagRemoved: ((any HashtagItem) -> Void)?
    public private(set) var insertedHashtags: [any HashtagItem] = []

    /// The trigger character ("@" or "#") of the mention session currently in
    /// progress, or nil when no session is active. Closure-based hosts can read
    /// this inside `onMentionQueryChanged` to tell the two apart.
    public private(set) var activeMentionTrigger: MentionTrigger?

    /// Protocol-based alternative to the `onMention*` closures. Setting this
    /// installs a bridge over `onMentionQueryChanged`, `onMentionInserted` and
    /// `onMentionRemoved` (replacing any closures assigned there); setting it
    /// back to nil clears them. Held weakly — the host app must retain the provider.
    public weak var mentionProvider: (any MentionSuggestionsProviding)? {
        didSet { installMentionProviderBridge() }
    }
    private var mentionProviderQueryGeneration = 0

    public var html: String {
        htmlString()
    }

    public var attributedContent: NSAttributedString {
        editorTextView.attributedText
    }

    public var markdown: String {
        attributedStringToMarkdown(editorTextView.attributedText)
    }

    /// Placeholder shown while the editor is empty.
    public var placeholder: String = "Start writing..." {
        didSet {
            guard isViewLoaded else { return }
            placeholderLabel.text = placeholder
        }
    }

    /// Padding around the editable content, applied to both the rich text
    /// and HTML text views. Defaults to a roomy inset tuned for a
    /// full-screen editor; set something close to `.zero` for a compact
    /// inline field that matches a plain `UITextView`'s default insets.
    public var contentInset = UIEdgeInsets(top: 22, left: 18, bottom: 22, right: 18) {
        didSet {
            guard isViewLoaded else { return }
            applyContentInset()
        }
    }

    /// Replaces the editor content with `markdown`, converted to the
    /// attributed string the editor displays in edit mode. Understands the
    /// dialect the `markdown` getter emits: `**bold**`, `*italic*`,
    /// `__underline__`, `~~strikethrough~~`, `[text](url)`, `#`–`######`
    /// headings, `- ` bullets, literal `1. ` numbered lists and 4-space
    /// list indents. Safe to call before the view is loaded.
    public func setMarkdown(_ markdown: String) {
        loadViewIfNeeded()
        setEditorContent(markdownToAttributedString(markdown))
    }

    /// Replaces the editor content with `html`. Safe to call before the
    /// view is loaded.
    public func setHTML(_ html: String) {
        loadViewIfNeeded()
        setEditorContent(attributedString(fromHTML: html))
        if editorMode == .html {
            htmlTextView.text = html
        }
    }

    /// Gives keyboard focus to the editor. Safe to call before the view is
    /// loaded (though the keyboard only appears once the view is in a window).
    public func focus() {
        loadViewIfNeeded()
        if editorMode == .html {
            htmlTextView.becomeFirstResponder()
        } else {
            editorTextView.becomeFirstResponder()
        }
    }

    /// Resigns keyboard focus from the editor.
    public func blur() {
        guard isViewLoaded else { return }
        editorTextView.resignFirstResponder()
        htmlTextView.resignFirstResponder()
    }

    private let richTextToolbarOptions: [ToolbarOption] = [
        .textStyle, .bold, .italic, .underline, .strikeThrough, .baseline, .clear, .separator,
        .alignment, .lists, .links, .colors, .separator,
        .undoRedo
    ]

    /// Matches the markdown toolbar design: flat buttons, no menus —
    /// + | B I U | bullet, numbered | outdent, indent | link, unlink.
    private let markdownToolbarOptions: [ToolbarOption] = [
        .bold, .italic, .underline,
        .bulletList, .numberedList,
        .outdent, .indent,
        .addLink, .removeLink
    ]

    private let editorTextView = UITextView()
    private let htmlTextView = UITextView()
    private let toolbarScrollView = UIScrollView()
    private let toolbarStackView = UIStackView()
    private let placeholderLabel = UILabel()
    private let mentionTableView = UITableView(frame: .zero, style: .plain)
    private var placeholderTopConstraint: NSLayoutConstraint?
    private var placeholderLeadingConstraint: NSLayoutConstraint?
    private var toolbarHeightConstraint: NSLayoutConstraint?

    /// A row in the mention/hashtag suggestion list — either a person
    /// (`MentionItem`) or a hashtag (`HashtagItem`). The two public
    /// protocols stay separate (hosts shouldn't have to reconcile
    /// avatar/self-mention concepts with hashtag colors); this enum is how
    /// the shared list/table plumbing stores either kind uniformly.
    enum MentionSuggestionEntry {
        case mention(any MentionItem)
        case hashtag(any HashtagItem)

        var displayName: String {
            switch self {
            case .mention(let item): return item.mentionDisplayName
            case .hashtag(let item): return item.hashtagDisplayName
            }
        }

        var identifier: String {
            switch self {
            case .mention(let item): return item.mentionIdentifier
            case .hashtag(let item): return item.hashtagIdentifier
            }
        }
    }

    private typealias MentionSection = (title: String?, suggestions: [MentionSuggestionEntry])

    private var filteredMentions: [MentionSuggestionEntry] = []
    private var mentionSections: [MentionSection] = []
    private var mentionQueryRange: NSRange?
    private var remoteMentionSuggestions: [MentionSuggestionEntry] = []
    private var isMentionSuggestionsLoading = false
    private var lastMentionQuery: String?
    private var lastMentionTrigger: MentionTrigger?
    private var mentionQueryTask: Task<Void, Never>?
    private let mentionImageCache = NSCache<NSURL, UIImage>()
    private var editorMode: EditorMode = .richText
    private var listMode: ListMode = .none
    private var orderedListCounter = 1
    private var selectedHeadingStyle: HeadingStyle = .paragraph
    private var isSyncingText = false
    private var toolbarButtons: [ToolbarItem: UIButton] = [:]
    private weak var listsMenuButton: UIButton?

    let baseFont = UIFont.preferredFont(forTextStyle: .body)
    let linkColor = UIColor.systemBlue

    public init(
        mentionConfiguration: MentionConfiguration = MentionConfiguration(),
        toolbarConfiguration: ToolbarConfiguration = ToolbarConfiguration()
    ) {
        self.mentionConfiguration = mentionConfiguration
        self.toolbarConfiguration = toolbarConfiguration
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        mentionConfiguration = MentionConfiguration()
        toolbarConfiguration = ToolbarConfiguration()
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureToolbar()
        configureTextViews()
        setInitialContent()
    }

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.key?.keyCode == .keyboardEscape }), mentionQueryRange != nil {
            endMentionSession()
            return
        }

        super.pressesBegan(presses, with: event)
    }

    public func updateMentionSuggestions(_ items: [any MentionItem]) {
        guard onMentionQueryChanged != nil, mentionQueryRange != nil, activeMentionTrigger != .hash else { return }
        remoteMentionSuggestions = uniqueMentionSuggestions(items).map { MentionSuggestionEntry.mention($0) }
        isMentionSuggestionsLoading = false
        filteredMentions = remoteMentionSuggestions
        mentionSections = makeMentionSections(from: filteredMentions)
        showMentionSuggestionsIfNeeded()
    }

    /// Same contract as `updateMentionSuggestions(_:)`, for "#" hashtag results.
    public func updateHashtagSuggestions(_ items: [any HashtagItem]) {
        guard onMentionQueryChanged != nil, mentionQueryRange != nil, activeMentionTrigger == .hash else { return }
        remoteMentionSuggestions = uniqueHashtagSuggestions(items).map { MentionSuggestionEntry.hashtag($0) }
        isMentionSuggestionsLoading = false
        filteredMentions = remoteMentionSuggestions
        mentionSections = makeMentionSections(from: filteredMentions)
        showMentionSuggestionsIfNeeded()
    }

    public func setMentionSuggestionsLoading(_ isLoading: Bool) {
        guard onMentionQueryChanged != nil, mentionQueryRange != nil else { return }
        isMentionSuggestionsLoading = isLoading
        if isLoading {
            mentionSections = []
            filteredMentions = []
        }
        showMentionSuggestionsIfNeeded()
    }

    private func installMentionProviderBridge() {
        mentionProviderQueryGeneration += 1

        guard mentionProvider != nil else {
            onMentionQueryChanged = nil
            onMentionInserted = nil
            onMentionRemoved = nil
            onHashtagInserted = nil
            onHashtagRemoved = nil
            return
        }

        onMentionQueryChanged = { [weak self] query in
            guard let self else { return }
            self.mentionProviderQueryGeneration += 1
            let generation = self.mentionProviderQueryGeneration

            guard let query else {
                self.setMentionSuggestionsLoading(false)
                self.mentionProvider?.mentionSessionDidEnd()
                return
            }

            // No loading placeholder here by design: showing one only to hide
            // it again the moment a query resolves to zero results is a flash
            // with nothing to show for it. The list simply updates (or stays
            // hidden) once results arrive.
            switch self.activeMentionTrigger ?? .at {
            case .at:
                self.mentionProvider?.fetchMentionSuggestions(for: query) { [weak self] items in
                    DispatchQueue.main.async {
                        guard let self, generation == self.mentionProviderQueryGeneration else { return }
                        self.updateMentionSuggestions(items)
                    }
                }
            case .hash:
                self.mentionProvider?.fetchHashtagSuggestions(for: query) { [weak self] items in
                    DispatchQueue.main.async {
                        guard let self, generation == self.mentionProviderQueryGeneration else { return }
                        self.updateHashtagSuggestions(items)
                    }
                }
            }
        }
        onMentionInserted = { [weak self] mention in
            self?.mentionProvider?.mentionInserted(mention)
        }
        onMentionRemoved = { [weak self] mention in
            self?.mentionProvider?.mentionRemoved(mention)
        }
        onHashtagInserted = { [weak self] hashtag in
            self?.mentionProvider?.hashtagInserted(hashtag)
        }
        onHashtagRemoved = { [weak self] hashtag in
            self?.mentionProvider?.hashtagRemoved(hashtag)
        }
    }
}

private extension RichTextEditorViewController {

    func configureView() {
        title = "ZSS Inspired Editor"
        view.backgroundColor = .systemBackground

        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.showsHorizontalScrollIndicator = false
        toolbarScrollView.showsVerticalScrollIndicator = false
        toolbarScrollView.alwaysBounceVertical = false
        toolbarScrollView.delegate = self
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
        configureMentionTableView()

        let toolbarHeightConstraint = toolbarScrollView.heightAnchor.constraint(equalToConstant: toolbarConfiguration.toolbarHeight)
        self.toolbarHeightConstraint = toolbarHeightConstraint

        NSLayoutConstraint.activate([
            toolbarScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarScrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            toolbarHeightConstraint,

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

    func configureMentionTableView() {
        mentionTableView.dataSource = self
        mentionTableView.delegate = self
        mentionTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MentionCell")
        mentionTableView.separatorInset = .zero
        mentionTableView.layoutMargins = .zero
        mentionTableView.sectionHeaderTopPadding = 0
        mentionTableView.layer.borderWidth = 1
        mentionTableView.layer.borderColor = UIColor.separator.cgColor
        mentionTableView.isHidden = true
        applyMentionConfiguration()
        view.addSubview(mentionTableView)
    }

    func applyMentionConfiguration() {
        // Self-sizing rather than a fixed `rowHeight`: `UIListContentConfiguration`
        // (avatar + name, or avatar + name + inline "You") needs more vertical
        // room than a single fixed height can guarantee for every row — a
        // fixed height was clipping avatar images. `rowHeight` still feeds
        // the *estimate* used to size/position the suggestion popup.
        mentionTableView.rowHeight = UITableView.automaticDimension
        mentionTableView.estimatedRowHeight = max(1, mentionConfiguration.rowHeight)
        mentionTableView.sectionHeaderHeight = mentionConfiguration.showsSuggestionSections ? max(1, mentionConfiguration.sectionHeaderHeight) : 0
        mentionTableView.layer.cornerRadius = max(0, mentionConfiguration.cornerRadius)
        mentionTableView.backgroundColor = mentionConfiguration.suggestionBackgroundColor
        mentionTableView.reloadData()
    }

    func configureToolbar() {
        toolbarStackView.arrangedSubviews.forEach { arrangedSubview in
            toolbarStackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        toolbarButtons.removeAll()

        if let plusButtonBehavior = resolvedPlusButtonBehavior() {
            addPlusButton(behavior: plusButtonBehavior)
            if contentMode == .richText {
                toolbarStackView.addArrangedSubview(separator())
            }
        }

        if toolbarConfiguration.showsModeControl {
            addToolbarMenuButton(title: "Mode", imageName: "square.2.layers.3d", menu: modeSelectionMenu())
            if contentMode == .richText {
                toolbarStackView.addArrangedSubview(separator())
            }
        }

        let options = contentMode == .richText ? richTextToolbarOptions : markdownToolbarOptions
        for option in options {
            switch option {
            case .textStyle:
                addToolbarMenuButton(title: "Text Style", imageName: "textformat.size", menu: headingMenu())
            case .bold:
                addToolbarButton(.bold, title: "B", imageName: "bold", action: #selector(toggleBold))
            case .italic:
                addToolbarButton(.italic, title: "I", imageName: "italic", action: #selector(toggleItalic))
            case .underline:
                addToolbarButton(.underline, title: "U", imageName: "underline", action: #selector(toggleUnderlineStyle))
            case .strikeThrough:
                addToolbarButton(.strikeThrough, title: "S", imageName: "strikethrough", action: #selector(toggleStrikeThroughStyle))
            case .baseline:
                addToolbarMenuButton(title: "Baseline", imageName: "textformat", menu: baselineMenu())
            case .clear:
                addToolbarButton(title: "Clear", imageName: "clear", action: #selector(removeFormatting))
            case .alignment:
                addToolbarMenuButton(title: "Alignment", imageName: "text.alignleft", menu: alignmentMenu())
            case .lists:
                listsMenuButton = addToolbarMenuButton(title: "Lists", imageName: "list.bullet", menu: listMenu())
            case .links:
                addToolbarMenuButton(title: "Links", imageName: "link", menu: linkMenu())
            case .colors:
                addToolbarMenuButton(title: "Colors", imageName: "paintpalette", menu: colorsMenu())
            case .undoRedo:
                addToolbarButton(title: "Undo", imageName: "arrow.uturn.backward", action: #selector(undo))
                addToolbarButton(title: "Redo", imageName: "arrow.uturn.forward", action: #selector(redo))
            case .separator:
                toolbarStackView.addArrangedSubview(separator())
            case .bulletList:
                addToolbarButton(.unorderedList, title: "Bullet List", imageName: "list.bullet", action: #selector(toggleUnorderedList))
            case .numberedList:
                addToolbarButton(.orderedList, title: "Numbered List", imageName: "list.number", action: #selector(toggleOrderedList))
            case .outdent:
                addToolbarButton(.outdent, title: "Decrease Indent", imageName: "decrease.indent", action: #selector(outdentSelection))
            case .indent:
                addToolbarButton(title: "Increase Indent", imageName: "increase.indent", action: #selector(indentSelection))
            case .addLink:
                addToolbarButton(.link, title: "Add Link", imageName: "link", action: #selector(insertLink))
            case .removeLink:
                addToolbarButton(.removeLink, title: "Remove Link", image: slashedSystemImage("link"), action: #selector(removeLink))
            }
        }
    }

    func configureTextViews() {
        editorTextView.delegate = self
        editorTextView.allowsEditingTextAttributes = true
        editorTextView.font = baseFont
        editorTextView.adjustsFontForContentSizeCategory = true
        editorTextView.backgroundColor = .systemBackground
        editorTextView.keyboardDismissMode = .interactive
        editorTextView.typingAttributes = defaultTypingAttributes()

        placeholderLabel.text = placeholder
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = baseFont
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        editorTextView.addSubview(placeholderLabel)

        let placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: editorTextView.topAnchor)
        let placeholderLeadingConstraint = placeholderLabel.leadingAnchor.constraint(equalTo: editorTextView.leadingAnchor)
        NSLayoutConstraint.activate([placeholderTopConstraint, placeholderLeadingConstraint])
        self.placeholderTopConstraint = placeholderTopConstraint
        self.placeholderLeadingConstraint = placeholderLeadingConstraint

        htmlTextView.delegate = self
        htmlTextView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        htmlTextView.backgroundColor = .systemGroupedBackground
        htmlTextView.autocorrectionType = .no
        htmlTextView.autocapitalizationType = .none
        htmlTextView.isHidden = true

        applyContentInset()
    }

    /// Drives `textContainerInset` on both text views and the placeholder's
    /// top/leading offset from `contentInset`. The placeholder gets an extra
    /// nudge matching the text container's line fragment padding so it lines
    /// up with the first glyph, the same way it does for the default inset.
    private func applyContentInset() {
        editorTextView.textContainerInset = contentInset
        htmlTextView.textContainerInset = contentInset
        let padding = editorTextView.textContainer.lineFragmentPadding
        placeholderTopConstraint?.constant = contentInset.top + padding
        placeholderLeadingConstraint?.constant = contentInset.left + padding
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
        addToolbarButton(item, title: title, image: imageName.flatMap(UIImage.init(systemName:)), action: action, accessibilityValue: accessibilityValue)
    }

    private func addToolbarButton(_ item: ToolbarItem? = nil, title: String, image: UIImage?, action: Selector, accessibilityValue: String? = nil) {
        var configuration = UIButton.Configuration.bordered()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        if let image {
            configuration.image = image
        } else {
            configuration.title = title
        }

        let button = UIButton(configuration: configuration)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: toolbarConfiguration.buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: toolbarConfiguration.buttonSize).isActive = true
        button.accessibilityLabel = title
        button.accessibilityValue = accessibilityValue
        button.configurationUpdateHandler = { button in
            var updatedConfiguration = button.configuration ?? .bordered()
            if button.isEnabled {
                updatedConfiguration.baseForegroundColor = button.isSelected ? .white : .label
                updatedConfiguration.baseBackgroundColor = button.isSelected ? .systemBlue : .clear
            } else {
                updatedConfiguration.baseForegroundColor = .tertiaryLabel
                updatedConfiguration.baseBackgroundColor = .clear
            }
            button.configuration = updatedConfiguration
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        toolbarStackView.addArrangedSubview(button)

        if let item {
            toolbarButtons[item] = button
        }
    }

    func addToolbarMenuButton(title: String, imageName: String, menu: UIMenu) -> UIButton {
        var configuration = UIButton.Configuration.bordered()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .label
        configuration.image = UIImage(systemName: imageName)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        let button = UIButton(configuration: configuration)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: toolbarConfiguration.buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: toolbarConfiguration.buttonSize).isActive = true
        button.accessibilityLabel = title
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        toolbarStackView.addArrangedSubview(button)
        return button
    }

    /// In markdown mode, `markdownPlusButtonBehavior` wins and its handlers are
    /// invoked with the markdown captured at tap time; otherwise the shared
    /// `plusButtonBehavior` is used.
    func resolvedPlusButtonBehavior() -> PlusButtonBehavior? {
        guard contentMode == .markdown, let markdownBehavior = toolbarConfiguration.markdownPlusButtonBehavior else {
            return toolbarConfiguration.plusButtonBehavior
        }

        func bridged(_ action: MarkdownToolbarAction) -> ToolbarAction {
            ToolbarAction(title: action.title, imageName: action.imageName) { [weak self] in
                guard let self else { return }
                action.handler(self.markdown)
            }
        }

        switch markdownBehavior {
        case .action(let action):
            return .action(bridged(action))
        case .menu(let actions):
            return .menu(actions.map(bridged))
        }
    }

    func addPlusButton(behavior: PlusButtonBehavior) {
        var configuration: UIButton.Configuration
        if contentMode == .markdown {
            configuration = .filled()
            configuration.baseBackgroundColor = toolbarConfiguration.plusButtonColor
            configuration.baseForegroundColor = .white
        } else {
            configuration = .bordered()
            configuration.baseForegroundColor = .label
        }
        configuration.cornerStyle = .medium
        configuration.image = UIImage(systemName: "plus")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        let button: UIButton
        switch behavior {
        case .action(let action):
            button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action.handler() })
            button.accessibilityLabel = action.title
        case .menu(let actions):
            button = UIButton(configuration: configuration)
            button.menu = externalActionsMenu(actions: actions)
            button.showsMenuAsPrimaryAction = true
            button.accessibilityLabel = "More Actions"
        }
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: toolbarConfiguration.buttonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: toolbarConfiguration.buttonSize).isActive = true
        toolbarStackView.addArrangedSubview(button)
    }

    func externalActionsMenu(actions: [ToolbarAction]) -> UIMenu {
        let menuActions = actions.map { action in
            UIAction(title: action.title, image: action.imageName.flatMap(UIImage.init(systemName:))) { _ in
                action.handler()
            }
        }
        return UIMenu(children: menuActions)
    }

    func headingMenu() -> UIMenu {
        let actions = HeadingStyle.allCases.map { style in
            UIAction(title: headingTitle(style)) { [weak self] _ in self?.applyHeadingStyle(style) }
        }
        return UIMenu(title: "Text Style", image: UIImage(systemName: "textformat.size"), children: actions)
    }

    func headingTitle(_ style: HeadingStyle) -> String {
        switch style {
        case .paragraph: return "Paragraph"
        case .h1: return "Heading 1"
        case .h2: return "Heading 2"
        case .h3: return "Heading 3"
        case .h4: return "Heading 4"
        case .h5: return "Heading 5"
        case .h6: return "Heading 6"
        }
    }

    func baselineMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Subscript", image: UIImage(systemName: "textformat.subscript")) { [weak self] _ in self?.toggleSubscript() },
            UIAction(title: "Superscript", image: UIImage(systemName: "textformat.superscript")) { [weak self] _ in self?.toggleSuperscript() }
        ])
    }

    func alignmentMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Align Left", image: UIImage(systemName: "text.alignleft")) { [weak self] _ in self?.applyAlignment(.left) },
            UIAction(title: "Align Center", image: UIImage(systemName: "text.aligncenter")) { [weak self] _ in self?.applyAlignment(.center) },
            UIAction(title: "Align Right", image: UIImage(systemName: "text.alignright")) { [weak self] _ in self?.applyAlignment(.right) },
            UIAction(title: "Justify", image: UIImage(systemName: "text.justify")) { [weak self] _ in self?.applyAlignment(.justified) }
        ])
    }

    func listMenu() -> UIMenu {
        let currentMode = currentListMode()
        var bulletAction = UIAction(title: "Bullet List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.toggleUnorderedList() }
        var numberedAction = UIAction(title: "Numbered List", image: UIImage(systemName: "list.number")) { [weak self] _ in self?.toggleOrderedList() }

        if currentMode == .unordered {
            bulletAction.attributes.insert(.disabled)
            bulletAction.state = .on
        }
        if currentMode == .ordered {
            numberedAction.attributes.insert(.disabled)
            numberedAction.state = .on
        }

        return UIMenu(children: [
            bulletAction,
            numberedAction,
            UIAction(title: "Increase Indent", image: UIImage(systemName: "increase.indent")) { [weak self] _ in self?.indentSelection() },
            UIAction(title: "Decrease Indent", image: UIImage(systemName: "decrease.indent")) { [weak self] _ in self?.outdentSelection() }
        ])
    }

    func insertMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Image", image: UIImage(systemName: "photo")) { [weak self] _ in self?.insertImagePlaceholder() },
            UIAction(title: "Horizontal Rule", image: UIImage(systemName: "minus")) { [weak self] _ in self?.insertHorizontalRule() }
        ])
    }

    func linkMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Add Link", image: UIImage(systemName: "link")) { [weak self] _ in self?.insertLink() },
            UIAction(title: "Remove Link", image: UIImage(systemName: "link.badge.minus"), attributes: .destructive) { [weak self] _ in self?.removeLink() }
        ])
    }

    func colorsMenu() -> UIMenu {
        UIMenu(children: [
            colorMenu(title: "Text Color", imageName: "character", colors: toolbarConfiguration.foregroundColors, attribute: .foregroundColor),
            colorMenu(title: "Background Color", imageName: "highlighter", colors: toolbarConfiguration.backgroundColors, attribute: .backgroundColor)
        ])
    }

    func colorMenu(title: String, imageName: String, colors: [ToolbarColor], attribute: NSAttributedString.Key) -> UIMenu {
        var actions = colors.map { color in
            UIAction(title: color.name, image: UIImage(systemName: "circle.fill")?.withTintColor(color.color, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.applyAttribute(attribute, value: color.color, range: self?.editorTextView.selectedRange ?? NSRange(location: 0, length: 0))
            }
        }
        actions.append(UIAction(title: "Clear Color", image: UIImage(systemName: "xmark.circle"), attributes: .destructive) { [weak self] _ in
            guard let self else { return }
            removeAttribute(attribute, range: editorTextView.selectedRange)
        })
        return UIMenu(title: title, image: UIImage(systemName: imageName), children: actions)
    }

    func modeSelectionMenu() -> UIMenu {
        let richTextAction = UIAction(
            title: "Rich Text",
            image: UIImage(systemName: "textformat"),
            state: contentMode == .richText ? .on : .off
        ) { [weak self] _ in
            self?.setContentMode(.richText)
        }
        let markdownAction = UIAction(
            title: "Markdown",
            image: UIImage(systemName: "number"),
            state: contentMode == .markdown ? .on : .off
        ) { [weak self] _ in
            self?.setContentMode(.markdown)
        }
        return UIMenu(children: [richTextAction, markdownAction])
    }

    func separator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return view
    }

    /// SF Symbols has no slashed link variant, so draw the symbol with a
    /// diagonal strikethrough (template image, tinted like any other icon).
    func slashedSystemImage(_ name: String) -> UIImage? {
        guard let base = UIImage(systemName: name) else { return nil }
        let size = base.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            base.withTintColor(.black).draw(in: CGRect(origin: .zero, size: size))
            let slash = UIBezierPath()
            slash.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.05))
            slash.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * 0.95))
            slash.lineWidth = 1.6
            slash.lineCapStyle = .round
            UIColor.black.setStroke()
            slash.stroke()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

private extension RichTextEditorViewController {

    private func setMode(_ mode: EditorMode) {
        editorMode = mode
        hideMentionSuggestions()
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
        applyHeadingStyle(headingStyle)
    }

    func applyHeadingStyle(_ headingStyle: HeadingStyle) {
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
        } else if listMode == .ordered {
            listMode = .unordered
            removeListMarkersFromCurrentParagraphs()
            applyListMarkersToCurrentParagraphs()
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
        } else if listMode == .unordered {
            listMode = .ordered
            orderedListCounter = 1
            removeListMarkersFromCurrentParagraphs()
            applyListMarkersToCurrentParagraphs()
        } else {
            listMode = .ordered
            orderedListCounter = 1
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
        let selectedRange = editorTextView.selectedRange
        let selectedText = selectedPlainText()
        let alert = UIAlertController(title: "Add Link", message: "Enter the text and destination URL.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Display text"
            textField.text = selectedText
        }
        alert.addTextField { textField in
            textField.placeholder = "https://example.com"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields, fields.count == 2 else { return }
            let displayText = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let urlText = fields[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let url = normalizedURL(from: urlText) else {
                presentInvalidURLAlert()
                return
            }

            let title = displayText.isEmpty ? url.absoluteString : displayText
            editorTextView.selectedRange = selectedRange

            // The link is restricted to the display text: typing after it
            // (space, newline, any character) must not extend the link.
            var trailingAttributes = editorTextView.typingAttributes
            trailingAttributes.removeValue(forKey: .link)
            trailingAttributes.removeValue(forKey: .underlineStyle)
            trailingAttributes[.foregroundColor] = UIColor.label

            let attributes = linkTypingAttributes(url: url)
            replaceSelection(with: NSAttributedString(string: title, attributes: attributes), selectedOffset: title.utf16.count)
            editorTextView.typingAttributes = trailingAttributes
        })
        present(alert, animated: true)
    }

    func normalizedURL(from text: String) -> URL? {
        guard !text.isEmpty else { return nil }
        let value = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: value), url.host != nil else { return nil }
        return url
    }

    func presentInvalidURLAlert() {
        let alert = UIAlertController(title: "Invalid URL", message: "Enter a valid URL and try again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

// Styling helpers shared with RichTextEditorViewController+Markdown.swift,
// so they are internal rather than part of the private extension below.
extension RichTextEditorViewController {

    func defaultParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacing = 8
        return style
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

    /// The trigger stored alongside a mention when it was inserted; mentions
    /// created before triggers existed fall back to "@".
    func mentionTrigger(in attributedText: NSAttributedString, at index: Int) -> MentionTrigger {
        guard let symbol = attributedText.attribute(.zssMentionTrigger, at: index, effectiveRange: nil) as? String,
              let character = symbol.first,
              let trigger = MentionTrigger(rawValue: character) else {
            return .at
        }
        return trigger
    }

    func escapedHTMLText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func escapedHTMLAttribute(_ text: String) -> String {
        escapedHTMLText(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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

        if selection.length > 0 {
            let location = min(selection.location, text.length - 1)
            var range = text.paragraphRange(for: NSRange(location: location, length: max(selection.length, 1)))
            if range.upperBound > editorTextView.attributedText.length {
                range.length = editorTextView.attributedText.length - range.location
            }
            return range
        }

        let cursorPos = selection.location

        if cursorPos == text.length && cursorPos > 0 {
            let prevChar = text.substring(with: NSRange(location: cursorPos - 1, length: 1))
            if prevChar == "\n" {
                return NSRange(location: cursorPos, length: 0)
            }
        }

        let location = min(cursorPos, text.length - 1)
        var range = text.paragraphRange(for: NSRange(location: location, length: 1))
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

        listsMenuButton?.menu = listMenu()

        toolbarButtons[.removeLink]?.isEnabled = selectionHasAttribute(.link)
        toolbarButtons[.outdent]?.isEnabled = currentIndentLevel() > 0
    }

    /// Indent level of the paragraph at the caret, in 24pt indent steps.
    private func currentIndentLevel() -> Int {
        let range = currentParagraphRange()
        guard range.location < editorTextView.attributedText.length,
              let style = editorTextView.attributedText.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle else {
            return 0
        }
        return max(0, Int((style.headIndent / 24).rounded()))
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

    /// Range to inspect for the current character/font attributes, or nil to
    /// fall back to `typingAttributes` (a bare caret with no selection: the
    /// attributes of the *next* character typed, which is what `typingAttributes`
    /// tracks — including attributes just toggled at the caret before any
    /// text has been typed to carry them).
    func selectionInspectionRange() -> NSRange? {
        let selection = editorTextView.selectedRange
        guard selection.length > 0 else { return nil }

        let textLength = editorTextView.attributedText.length
        return NSRange(location: selection.location, length: min(selection.length, textLength - selection.location))
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

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        guard range.location >= 0 && range.location + range.length <= mutableText.string.count else { return }

        let paragraph = (mutableText.string as NSString).substring(with: range)

        if paragraph.hasListMarker {
            updateToolbarSelectionState()
            return
        }

        let marker: String
        switch listMode {
        case .unordered:
            marker = "• "
        case .ordered:
            marker = "\(orderedListCounter). "
            orderedListCounter += 1
        case .none:
            return
        }

        mutableText.insert(NSAttributedString(string: marker, attributes: editorTextView.typingAttributes), at: range.location)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: range.location + marker.count, length: 0)
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
        editorTextView.selectedRange = NSRange(location: range.location, length: 0)
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
        let trimmedPrevious = previousLine.trimmingCharacters(in: .whitespaces)
        let hasBullet = trimmedPrevious.hasPrefix("•")
        let hasNumber = previousLine.orderedListNumber != nil

        switch listMode {
        case .none:
            if hasBullet {
                return "• "
            }
            if let number = previousLine.orderedListNumber {
                return "\(number + 1). "
            }
            return nil
        case .unordered:
            return hasBullet ? "• " : nil
        case .ordered:
            guard hasNumber else { return nil }
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
        mentionAwareHTMLString()
    }

    func defaultHTMLString() -> String {
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

    func mentionAwareHTMLString() -> String {
        let attributedText = editorTextView.attributedText ?? NSAttributedString()
        var html = ""
        var index = 0
        while index < attributedText.length {
            var effectiveRange = NSRange(location: 0, length: 0)
            if let mention = attributedText.attribute(.zssMentionItem, at: index, effectiveRange: &effectiveRange) as? any MentionItem {
                html += exportedMentionHTML(for: mention, trigger: mentionTrigger(in: attributedText, at: index))
            } else if let hashtag = attributedText.attribute(.zssHashtagItem, at: index, effectiveRange: &effectiveRange) as? any HashtagItem {
                html += exportedHashtagHTML(for: hashtag)
            } else if attributedText.attribute(.attachment, at: index, effectiveRange: &effectiveRange) is NSTextAttachment {
                html += ""
            } else {
                let string = attributedText.attributedSubstring(from: effectiveRange).string
                html += escapedHTMLText(string)
            }
            index = effectiveRange.upperBound
        }
        return html.replacingOccurrences(of: "\n", with: "<br>")
    }

    func exportedMentionHTML(for mention: any MentionItem, trigger: MentionTrigger) -> String {
        let escapedName = escapedHTMLText(mention.mentionDisplayName)
        let escapedIdentifier = escapedHTMLAttribute(mention.mentionIdentifier)
        switch mentionConfiguration.exportFormat {
        case .anchor:
            return "<a class=\"mention\" data-mention-id=\"\(escapedIdentifier)\">\(trigger.symbol)\(escapedName)</a>"
        case .custom(let formatter):
            return formatter(mention, escapedName, escapedIdentifier)
        }
    }

    func exportedHashtagHTML(for hashtag: any HashtagItem) -> String {
        let escapedName = escapedHTMLText(hashtag.hashtagDisplayName)
        let escapedIdentifier = escapedHTMLAttribute(hashtag.hashtagIdentifier)
        return "<a class=\"hashtag\" data-hashtag-id=\"\(escapedIdentifier)\">\(MentionTrigger.hash.symbol)\(escapedName)</a>"
    }

    func syncHTMLToEditor() {
        editorTextView.attributedText = attributedString(fromHTML: htmlTextView.text)
        editorTextView.typingAttributes = defaultTypingAttributes()
        updatePlaceholder()
        refreshInsertedMentionsAndHashtags()
    }

    func attributedString(fromHTML html: String) -> NSAttributedString {
        guard
            let data = html.data(using: .utf8),
            let attributedText = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            return NSAttributedString(string: html, attributes: defaultTypingAttributes())
        }
        return attributedText
    }

    /// Shared tail of the public content setters: installs the new content,
    /// resets editing state that referred to the old text, and refreshes UI.
    func setEditorContent(_ content: NSAttributedString) {
        endMentionSession()
        editorTextView.attributedText = content
        editorTextView.typingAttributes = defaultTypingAttributes()
        editorTextView.selectedRange = NSRange(location: content.length, length: 0)
        listMode = .none
        orderedListCounter = 1
        updatePlaceholder()
        updateToolbarSelectionState()
        refreshInsertedMentionsAndHashtags()
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

    func updateMentionSuggestions() {
        guard let queryRange = activeMentionQueryRange() else {
            endMentionSession()
            return
        }

        let matchedText = (editorTextView.text as NSString).substring(with: queryRange)
        let trigger = matchedText.first.flatMap(MentionTrigger.init(rawValue:)) ?? .at
        let query = String(matchedText.dropFirst())
        mentionQueryRange = queryRange
        activeMentionTrigger = trigger

        if onMentionQueryChanged != nil {
            if lastMentionQuery != query || lastMentionTrigger != trigger {
                scheduleMentionQueryChanged(query)
            }
            filteredMentions = remoteMentionSuggestions
            mentionSections = makeMentionSections(from: filteredMentions)
            showMentionSuggestionsIfNeeded()
            return
        }

        let lowercaseQuery = query.lowercased()
        let localEntries: [MentionSuggestionEntry]
        switch trigger {
        case .at:
            localEntries = allMentionSuggestions().map { MentionSuggestionEntry.mention($0) }
        case .hash:
            localEntries = allHashtagSuggestions().map { MentionSuggestionEntry.hashtag($0) }
        }
        filteredMentions = localEntries
            .filter { lowercaseQuery.isEmpty || $0.displayName.lowercased().hasPrefix(lowercaseQuery) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        mentionSections = makeMentionSections(from: filteredMentions)
        showMentionSuggestionsIfNeeded()
    }

    func allMentionSuggestions() -> [any MentionItem] {
        uniqueMentionSuggestions(mentionConfiguration.suggestions)
    }

    func uniqueMentionSuggestions(_ suggestions: [any MentionItem]) -> [any MentionItem] {
        var seenIdentifiers = Set<String>()
        return suggestions.filter {
            seenIdentifiers.insert($0.mentionIdentifier).inserted
        }
    }

    func allHashtagSuggestions() -> [any HashtagItem] {
        uniqueHashtagSuggestions(mentionConfiguration.hashtagSuggestions)
    }

    func uniqueHashtagSuggestions(_ suggestions: [any HashtagItem]) -> [any HashtagItem] {
        var seenIdentifiers = Set<String>()
        return suggestions.filter {
            seenIdentifiers.insert($0.hashtagIdentifier).inserted
        }
    }

    func isSelfMention(_ suggestion: any MentionItem) -> Bool {
        suggestion.isSelfMention
    }

    /// Groups suggestions into "People"/"Team"/"Hashtags" sections (titles
    /// sourced from `MentionConfiguration` so hosts can localize them),
    /// dropping any section that ends up empty.
    private func makeMentionSections(from suggestions: [MentionSuggestionEntry]) -> [MentionSection] {
        guard mentionConfiguration.showsSuggestionSections else {
            return [(title: nil, suggestions: suggestions)]
        }

        let people = suggestions.filter { if case .mention(let item) = $0 { return !item.isTeamMention }; return false }
        let teams = suggestions.filter { if case .mention(let item) = $0 { return item.isTeamMention }; return false }
        let hashtags = suggestions.filter { if case .hashtag = $0 { return true }; return false }

        return [
            (title: mentionConfiguration.peopleSectionTitle, suggestions: people),
            (title: mentionConfiguration.teamSectionTitle, suggestions: teams),
            (title: mentionConfiguration.hashtagSectionTitle, suggestions: hashtags)
        ].filter { !$0.suggestions.isEmpty }
    }

    func showMentionSuggestionsIfNeeded() {
        guard mentionQueryRange != nil else {
            hideMentionSuggestions()
            return
        }

        guard isMentionSuggestionsLoading || !filteredMentions.isEmpty else {
            hideMentionSuggestions(endingSession: false, preservesQuery: onMentionQueryChanged != nil)
            return
        }

        mentionTableView.reloadData()
        positionMentionTable(at: editorTextView.selectedRange.location)
        mentionTableView.isHidden = false
        view.bringSubviewToFront(mentionTableView)
    }

    func positionMentionTable(at mentionLocation: Int) {
        guard let textPosition = editorTextView.position(from: editorTextView.beginningOfDocument, offset: mentionLocation) else { return }

        let caretFrame = editorTextView.convert(editorTextView.caretRect(for: textPosition), to: view)
        let margin: CGFloat = 12
        let spacing: CGFloat = 4
        let width = min(max(1, mentionConfiguration.listWidth), view.bounds.width - (margin * 2))
        let rowCount = isMentionSuggestionsLoading ? 1 : filteredMentions.count
        let visibleRows = min(rowCount, max(1, mentionConfiguration.maximumVisibleRows))
        let visibleSectionCount = mentionConfiguration.showsSuggestionSections ? min(mentionSections.count, visibleRows) : 0
        let desiredHeight = (CGFloat(visibleRows) * max(1, mentionConfiguration.rowHeight))
            + (CGFloat(visibleSectionCount) * mentionTableView.sectionHeaderHeight)
        let x = min(max(caretFrame.minX, margin), view.bounds.width - width - margin)
        let minimumTop = view.safeAreaInsets.top + margin
        let maximumBottom = toolbarScrollView.frame.minY - spacing
        let availableBelow = max(0, maximumBottom - caretFrame.maxY - spacing)
        let availableAbove = max(0, caretFrame.minY - spacing - minimumTop)
        let placeBelow = availableBelow >= desiredHeight || availableBelow >= availableAbove
        let height = min(desiredHeight, placeBelow ? availableBelow : availableAbove)
        let y = placeBelow ? caretFrame.maxY + spacing : caretFrame.minY - spacing - height

        mentionTableView.frame = CGRect(x: x, y: y, width: width, height: height)
    }

    func activeMentionQueryRange() -> NSRange? {
        let selection = editorTextView.selectedRange
        guard selection.length == 0, selection.location <= editorTextView.text.utf16.count else { return nil }

        let triggers = mentionConfiguration.triggers
        guard !triggers.isEmpty else { return nil }

        let triggerClass = triggers
            .map { NSRegularExpression.escapedPattern(for: $0.symbol) }
            .joined()
        let prefixRange = NSRange(location: 0, length: selection.location)
        let expression = try? NSRegularExpression(pattern: "(?<!\\S)[\(triggerClass)][A-Za-z0-9_]*$")
        return expression?.firstMatch(in: editorTextView.text, range: prefixRange)?.range
    }

    func hideMentionSuggestions(endingSession: Bool = true, preservesQuery: Bool = false) {
        if !preservesQuery {
            mentionQueryRange = nil
            activeMentionTrigger = nil
        }
        filteredMentions = []
        mentionSections = []
        if !preservesQuery {
            remoteMentionSuggestions = []
        }
        isMentionSuggestionsLoading = false
        mentionTableView.isHidden = true
        if endingSession {
            cancelPendingMentionQuery()
        }
    }

    func endMentionSession() {
        guard mentionQueryRange != nil || lastMentionQuery != nil || !mentionTableView.isHidden else {
            hideMentionSuggestions()
            return
        }

        hideMentionSuggestions()
        onMentionQueryChanged?(nil)
    }

    func scheduleMentionQueryChanged(_ query: String) {
        lastMentionQuery = query
        lastMentionTrigger = activeMentionTrigger
        mentionQueryTask?.cancel()
        mentionQueryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.mentionQueryRange != nil, self.lastMentionQuery == query else { return }
                self.onMentionQueryChanged?(query)
            }
        }
    }

    func cancelPendingMentionQuery() {
        mentionQueryTask?.cancel()
        mentionQueryTask = nil
        lastMentionQuery = nil
        lastMentionTrigger = nil
    }

    func mentionSuggestion(at indexPath: IndexPath) -> MentionSuggestionEntry? {
        guard indexPath.section < mentionSections.count else { return nil }
        let suggestions = mentionSections[indexPath.section].suggestions
        guard indexPath.row < suggestions.count else { return nil }
        return suggestions[indexPath.row]
    }

    func mentionImage(for suggestion: any MentionItem) -> UIImage {
        switch suggestion.mentionImage {
        case .uiImage(let image):
            return avatarImage(from: image)
        case .initials(let initials):
            return initialsImage(initials, colorSeed: suggestion.mentionDisplayName)
        case .url(let url):
            guard let cachedImage = mentionImageCache.object(forKey: url as NSURL) else {
                return initialsImage(initials(for: suggestion.mentionDisplayName), colorSeed: suggestion.mentionDisplayName)
            }
            return avatarImage(from: cachedImage)
        case nil:
            return initialsImage(initials(for: suggestion.mentionDisplayName), colorSeed: suggestion.mentionDisplayName)
        }
    }

    /// Renders `sourceImage` into the same fixed `imageSize` × `imageSize`
    /// canvas `initialsImage` uses, aspect-fitted and clipped to
    /// `mentionConfiguration.imageShape`, so a real photo and an initials
    /// fallback are always the same size and shape regardless of the
    /// source image's own dimensions/aspect ratio. Aspect-*fit* (not fill):
    /// a non-square source (e.g. a full-body illustration/sticker rather
    /// than a square headshot) is shown in full — never cropped — even if
    /// that means empty space on two sides within the circle/rounded-rect.
    func avatarImage(from sourceImage: UIImage) -> UIImage {
        let imageSize = max(1, mentionConfiguration.imageSize)
        let size = CGSize(width: imageSize, height: imageSize)
        let bounds = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            avatarPath(in: bounds).addClip()
            sourceImage.draw(in: aspectFitRect(for: sourceImage.size, in: bounds))
        }
    }

    /// The rect to draw a `sourceSize` image in so it fits entirely within
    /// `bounds` while preserving its aspect ratio (no cropping), centered.
    func aspectFitRect(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return bounds }

        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(x: bounds.midX - scaledSize.width / 2, y: bounds.midY - scaledSize.height / 2)
        return CGRect(origin: origin, size: scaledSize)
    }

    func loadMentionImage(for suggestion: any MentionItem, at indexPath: IndexPath) {
        guard case .url(let url) = suggestion.mentionImage, mentionImageCache.object(forKey: url as NSURL) == nil else { return }

        Task { [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return }
            mentionImageCache.setObject(image, forKey: url as NSURL)
            guard mentionSuggestion(at: indexPath)?.identifier == suggestion.mentionIdentifier else { return }
            mentionTableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func initials(for name: String) -> String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    func initialsImage(_ initials: String, colorSeed: String) -> UIImage {
        let imageSize = max(1, mentionConfiguration.imageSize)
        let size = CGSize(width: imageSize, height: imageSize)
        let bounds = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            initialsBackgroundColor(for: colorSeed).setFill()
            avatarPath(in: bounds).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: imageSize * 0.36, weight: .semibold),
                .foregroundColor: mentionConfiguration.mentionForegroundColor
            ]
            let text = initials as NSString
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }
    }

    func initialsBackgroundColor(for seed: String) -> UIColor {
        guard !mentionConfiguration.initialsBackgroundColors.isEmpty else {
            return mentionConfiguration.mentionBackgroundColor
        }

        let index = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let colorIndex = Int(UInt(bitPattern: index) % UInt(mentionConfiguration.initialsBackgroundColors.count))
        return mentionConfiguration.initialsBackgroundColors[colorIndex]
    }

    func avatarPath(in bounds: CGRect) -> UIBezierPath {
        switch mentionConfiguration.imageShape {
        case .circle:
            return UIBezierPath(ovalIn: bounds)
        case .roundedRectangle(let cornerRadius):
            return UIBezierPath(roundedRect: bounds, cornerRadius: max(0, cornerRadius))
        }
    }

    func imageCornerRadius() -> CGFloat {
        switch mentionConfiguration.imageShape {
        case .circle:
            return max(1, mentionConfiguration.imageSize) / 2
        case .roundedRectangle(let cornerRadius):
            return max(0, cornerRadius)
        }
    }

    /// Renders `text` as a rounded pill of `foregroundColor`-on-`backgroundColor`,
    /// sized to fit at the editor's current typing font. Shared by the "@"
    /// mention and "#" hashtag pills.
    func pillAttachment(text: String, foregroundColor: UIColor, backgroundColor: UIColor, cornerRadius: CGFloat) -> NSTextAttachment {
        let font = editorTextView.typingAttributes[.font] as? UIFont ?? baseFont
        let horizontalPadding = max(0, mentionConfiguration.mentionHorizontalPadding)
        let verticalPadding = max(0, mentionConfiguration.mentionVerticalPadding)
        let nsText = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foregroundColor]
        let textSize = nsText.size(withAttributes: attributes)
        let size = CGSize(width: ceil(textSize.width + (horizontalPadding * 2)), height: ceil(textSize.height + (verticalPadding * 2)))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            backgroundColor.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: max(0, cornerRadius)).fill()
            nsText.draw(at: CGPoint(x: horizontalPadding, y: verticalPadding), withAttributes: attributes)
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: font.descender - verticalPadding, width: size.width, height: size.height)
        return attachment
    }

    func mentionPillAttachment(for suggestion: any MentionItem) -> NSTextAttachment {
        let isSelf = isSelfMention(suggestion)
        return pillAttachment(
            text: suggestion.mentionDisplayName,
            foregroundColor: isSelf ? mentionConfiguration.mentionForegroundColor : mentionConfiguration.otherMentionForegroundColor,
            backgroundColor: isSelf ? mentionConfiguration.mentionBackgroundColor : mentionConfiguration.otherMentionBackgroundColor,
            cornerRadius: mentionConfiguration.mentionCornerRadius
        )
    }

    /// Filled pill (same look as a non-self "@" mention pill), with the "#"
    /// shown as part of the visible text.
    func hashtagPillAttachment(for hashtag: any HashtagItem) -> NSTextAttachment {
        pillAttachment(
            text: MentionTrigger.hash.symbol + hashtag.hashtagDisplayName,
            foregroundColor: mentionConfiguration.otherMentionForegroundColor,
            backgroundColor: mentionConfiguration.otherMentionBackgroundColor,
            cornerRadius: mentionConfiguration.mentionCornerRadius
        )
    }

    /// Composes the "#" badge + outlined colored pill shown for a hashtag
    /// suggestion row as a single image, so the two parts can be
    /// independently shaped and spaced rather than shoehorned into
    /// `UIListContentConfiguration`'s single image + text pairing.
    func hashtagRowImage(for hashtag: any HashtagItem) -> UIImage {
        let badgeSize = max(1, mentionConfiguration.hashtagBadgeSize)
        let badgeFont = UIFont.systemFont(ofSize: badgeSize * 0.5, weight: .semibold)
        let pillFont = UIFont.preferredFont(forTextStyle: .body)
        let horizontalPadding: CGFloat = 14
        let verticalPadding: CGFloat = 7
        let gap: CGFloat = 10
        let strokeWidth: CGFloat = 1.5

        let color = hashtag.hashtagColor ?? .label
        let pillText = hashtag.hashtagDisplayName as NSString
        let pillAttributes: [NSAttributedString.Key: Any] = [.font: pillFont, .foregroundColor: color]
        let pillTextSize = pillText.size(withAttributes: pillAttributes)
        let pillSize = CGSize(
            width: ceil(pillTextSize.width + horizontalPadding * 2),
            height: ceil(pillTextSize.height + verticalPadding * 2)
        )

        let rowHeight = max(badgeSize, pillSize.height)
        let size = CGSize(width: badgeSize + gap + pillSize.width, height: rowHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let badgeRect = CGRect(x: 0, y: (rowHeight - badgeSize) / 2, width: badgeSize, height: badgeSize)
            mentionConfiguration.hashtagBadgeBackgroundColor.setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeSize * 0.3).fill()

            let badgeText = MentionTrigger.hash.symbol as NSString
            let badgeAttributes: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: mentionConfiguration.hashtagBadgeForegroundColor]
            let badgeTextSize = badgeText.size(withAttributes: badgeAttributes)
            badgeText.draw(
                at: CGPoint(x: badgeRect.midX - badgeTextSize.width / 2, y: badgeRect.midY - badgeTextSize.height / 2),
                withAttributes: badgeAttributes
            )

            let pillRect = CGRect(x: badgeSize + gap, y: (rowHeight - pillSize.height) / 2, width: pillSize.width, height: pillSize.height)
            let strokeRect = pillRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
            let pillPath = UIBezierPath(roundedRect: strokeRect, cornerRadius: strokeRect.height / 2)
            pillPath.lineWidth = strokeWidth
            color.setStroke()
            pillPath.stroke()
            pillText.draw(at: CGPoint(x: pillRect.minX + horizontalPadding, y: pillRect.minY + verticalPadding), withAttributes: pillAttributes)
        }
    }

    func insertMention(_ entry: MentionSuggestionEntry) {
        guard let queryRange = mentionQueryRange else { return }
        let trigger = activeMentionTrigger ?? .at

        var trailingAttributes = editorTextView.typingAttributes
        trailingAttributes.removeValue(forKey: .backgroundColor)
        trailingAttributes[.foregroundColor] = UIColor.label

        let attachment: NSTextAttachment
        switch entry {
        case .mention(let item):
            attachment = mentionPillAttachment(for: item)
        case .hashtag(let item):
            attachment = hashtagPillAttachment(for: item)
        }

        let replacement = NSMutableAttributedString(attachment: attachment)
        let attachmentRange = NSRange(location: 0, length: replacement.length)
        // Without an explicit .font here, the attachment character has none —
        // if the caret ends up adjacent to it (e.g. backspacing right after a
        // mention that's the first thing in the document), UITextView derives
        // typingAttributes from this character and falls back to a small
        // system default font, shrinking whatever's typed next.
        replacement.addAttributes(trailingAttributes, range: attachmentRange)
        switch entry {
        case .mention(let item):
            replacement.addAttribute(.zssMentionItem, value: item, range: attachmentRange)
        case .hashtag(let item):
            replacement.addAttribute(.zssHashtagItem, value: item, range: attachmentRange)
        }
        replacement.addAttribute(.zssMentionTrigger, value: trigger.symbol, range: attachmentRange)
        replacement.append(NSAttributedString(string: " ", attributes: trailingAttributes))

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.replaceCharacters(in: queryRange, with: replacement)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: queryRange.location + replacement.length, length: 0)
        editorTextView.typingAttributes = trailingAttributes
        endMentionSession()
        updatePlaceholder()
        updateToolbarSelectionState()
        refreshInsertedMentionsAndHashtags()
        switch entry {
        case .mention(let item):
            onMentionInserted?(item)
        case .hashtag(let item):
            onHashtagInserted?(item)
        }
    }

    func refreshInsertedMentionsAndHashtags() {
        let previousMentions = insertedMentions
        let currentMentions = currentMentionItems()
        insertedMentions = currentMentions

        var currentMentionCounts = Dictionary(currentMentions.map { ($0.mentionIdentifier, 1) }, uniquingKeysWith: +)
        for mention in previousMentions {
            let remainingCount = currentMentionCounts[mention.mentionIdentifier] ?? 0
            if remainingCount > 0 {
                currentMentionCounts[mention.mentionIdentifier] = remainingCount - 1
            } else {
                onMentionRemoved?(mention)
            }
        }

        let previousHashtags = insertedHashtags
        let currentHashtags = currentHashtagItems()
        insertedHashtags = currentHashtags

        var currentHashtagCounts = Dictionary(currentHashtags.map { ($0.hashtagIdentifier, 1) }, uniquingKeysWith: +)
        for hashtag in previousHashtags {
            let remainingCount = currentHashtagCounts[hashtag.hashtagIdentifier] ?? 0
            if remainingCount > 0 {
                currentHashtagCounts[hashtag.hashtagIdentifier] = remainingCount - 1
            } else {
                onHashtagRemoved?(hashtag)
            }
        }
    }

    func currentMentionItems() -> [any MentionItem] {
        let attributedText = editorTextView.attributedText ?? NSAttributedString()
        var mentions: [any MentionItem] = []
        attributedText.enumerateAttribute(.zssMentionItem, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            guard let mention = value as? any MentionItem else { return }
            mentions.append(mention)
        }
        return mentions
    }

    func currentHashtagItems() -> [any HashtagItem] {
        let attributedText = editorTextView.attributedText ?? NSAttributedString()
        var hashtags: [any HashtagItem] = []
        attributedText.enumerateAttribute(.zssHashtagItem, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            guard let hashtag = value as? any HashtagItem else { return }
            hashtags.append(hashtag)
        }
        return hashtags
    }
}

extension RichTextEditorViewController: UIScrollViewDelegate {

    /// The toolbar only ever scrolls horizontally; clamp out any vertical
    /// offset a drag or bounce introduces instead of relying solely on
    /// `alwaysBounceVertical`/layout to keep its content height pinned.
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == toolbarScrollView, scrollView.contentOffset.y != 0 else { return }
        scrollView.contentOffset.y = 0
    }
}

extension RichTextEditorViewController: UITextViewDelegate {

    public func textViewDidChange(_ textView: UITextView) {
        guard !isSyncingText else { return }
        if textView == editorTextView {
            if editorTextView.text.isEmpty && listMode != .none {
                listMode = .none
                orderedListCounter = 1
            } else if listMode != .none && currentListMode() == .none {
                listMode = .none
                orderedListCounter = 1
            }
            updatePlaceholder()
            updateToolbarSelectionState()
            updateMentionSuggestions()
            refreshInsertedMentionsAndHashtags()
        }
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView == editorTextView, !isSyncingText else { return }
        updateToolbarSelectionState()
        updateMentionSuggestions()
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

extension RichTextEditorViewController: UITableViewDataSource, UITableViewDelegate {

    public func numberOfSections(in tableView: UITableView) -> Int {
        if isMentionSuggestionsLoading { return 1 }
        return mentionSections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isMentionSuggestionsLoading { return 1 }
        guard section < mentionSections.count else { return 0 }
        return mentionSections[section].suggestions.count
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isMentionSuggestionsLoading, section < mentionSections.count else { return nil }
        guard let title = mentionSections[section].title else { return nil }

        let headerView = UIView()
        headerView.backgroundColor = mentionConfiguration.sectionHeaderBackgroundColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = mentionConfiguration.sectionHeaderForegroundColor
        headerView.addSubview(label)

        // Separates each "People"/"Team"/"Hashtags" header from its own
        // rows below it.
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        headerView.addSubview(separator)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return headerView
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MentionCell", for: indexPath)
        if isMentionSuggestionsLoading {
            var configuration = cell.defaultContentConfiguration()
            configuration.text = mentionConfiguration.loadingText
            configuration.textProperties.color = mentionConfiguration.sectionHeaderForegroundColor
            configuration.image = UIImage(systemName: "clock")
            cell.contentConfiguration = configuration
            cell.backgroundColor = mentionConfiguration.suggestionBackgroundColor
            cell.selectionStyle = .none
            return cell
        }

        guard let entry = mentionSuggestion(at: indexPath) else { return cell }
        switch entry {
        case .mention(let suggestion):
            configureMentionCell(cell, for: suggestion, at: indexPath)
        case .hashtag(let hashtag):
            configureHashtagCell(cell, for: hashtag)
        }

        cell.backgroundColor = mentionConfiguration.suggestionBackgroundColor
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero
        cell.selectionStyle = .default
        let sectionSuggestionCount = indexPath.section < mentionSections.count ? mentionSections[indexPath.section].suggestions.count : 0
        cell.separatorInset = sectionSuggestionCount == 1
            ? UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
            : .zero
        return cell
    }

    private func configureMentionCell(_ cell: UITableViewCell, for suggestion: any MentionItem, at indexPath: IndexPath) {
        var configuration = cell.defaultContentConfiguration()
        // The self-mention label is appended inline (rather than as
        // `secondaryText`, a second line below the name) because the
        // table's row height is a single fixed value shared by every row
        // (`mentionConfiguration.rowHeight`) — a second line there would
        // get clipped instead of growing the row.
        if isSelfMention(suggestion) {
            let font = configuration.textProperties.font
            let text = NSMutableAttributedString(
                string: suggestion.mentionDisplayName,
                attributes: [.font: font, .foregroundColor: mentionConfiguration.suggestionForegroundColor]
            )
            text.append(NSAttributedString(
                string: "  \(mentionConfiguration.selfMentionLabel)",
                attributes: [.font: font, .foregroundColor: mentionConfiguration.sectionHeaderForegroundColor]
            ))
            configuration.attributedText = text
        } else {
            configuration.text = suggestion.mentionDisplayName
            configuration.textProperties.color = mentionConfiguration.suggestionForegroundColor
        }
        configuration.image = mentionImage(for: suggestion)
        let imageSize = max(1, mentionConfiguration.imageSize)
        configuration.imageProperties.maximumSize = CGSize(width: imageSize, height: imageSize)
        configuration.imageProperties.cornerRadius = imageCornerRadius()
        cell.contentConfiguration = configuration
        loadMentionImage(for: suggestion, at: indexPath)
    }

    /// Hashtag rows don't use the avatar + name layout: the "#" badge and
    /// colored outlined pill are composed into a single image (via
    /// `hashtagRowImage(for:)`) so they can be independently shaped and
    /// spaced, rather than shoehorned into `UIListContentConfiguration`'s
    /// image + text pairing.
    private func configureHashtagCell(_ cell: UITableViewCell, for hashtag: any HashtagItem) {
        var configuration = cell.defaultContentConfiguration()
        configuration.text = nil
        configuration.secondaryText = nil
        let rowImage = hashtagRowImage(for: hashtag)
        configuration.image = rowImage
        configuration.imageProperties.maximumSize = rowImage.size
        configuration.imageProperties.cornerRadius = 0
        cell.contentConfiguration = configuration
        cell.accessibilityLabel = "\(MentionTrigger.hash.symbol)\(hashtag.hashtagDisplayName)"
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isMentionSuggestionsLoading else { return }
        guard let entry = mentionSuggestion(at: indexPath) else { return }

        guard case .mention(let item) = entry, let resolve = mentionConfiguration.resolveMentionBeforeInsertion else {
            insertMention(entry)
            return
        }

        setMentionSuggestionsLoading(true)
        resolve(item) { [weak self] resolvedItem in
            guard let self else { return }
            self.setMentionSuggestionsLoading(false)
            self.insertMention(.mention(resolvedItem))
        }
    }
}

extension NSAttributedString.Key {
    static let zssMentionItem = NSAttributedString.Key("com.zssinspirededitor.mentionItem")
    static let zssHashtagItem = NSAttributedString.Key("com.zssinspirededitor.hashtagItem")
    static let zssMentionTrigger = NSAttributedString.Key("com.zssinspirededitor.mentionTrigger")
}

private extension String {

    var hasListMarker: Bool {
        listMarkerRange != nil
    }

    var listMarkerRange: NSRange? {
        let nsString = self as NSString
        if range(of: #"^\s*•\s?"#, options: .regularExpression) != nil {
            return nsString.range(of: #"^\s*•\s?"#, options: .regularExpression)
        }

        let orderedRange = nsString.range(of: #"^\s*\d+\.\s*"#, options: .regularExpression)
        return orderedRange.location == NSNotFound ? nil : orderedRange
    }

    var orderedListNumber: Int? {
        let nsString = self as NSString
        let range = nsString.range(of: #"^\s*(\d+)\.\s*"#, options: .regularExpression)
        guard range.location != NSNotFound else { return nil }

        let marker = nsString.substring(with: range)
        return Int(marker.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ""))
    }
}
