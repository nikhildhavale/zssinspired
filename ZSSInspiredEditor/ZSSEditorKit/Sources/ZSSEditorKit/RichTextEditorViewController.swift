import UIKit

public final class RichTextEditorViewController: UIViewController {

    public enum MentionImage {
        case uiImage(UIImage)
        case url(URL)
        case initials(String)
    }

    public enum MentionImageShape {
        case circle
        case roundedRectangle(cornerRadius: CGFloat)
    }

    public enum MentionExportFormat {
        case anchor
        case custom((_ mention: any MentionItem, _ escapedName: String, _ escapedIdentifier: String) -> String)
    }

    public protocol MentionItem {
        var mentionIdentifier: String { get }
        var name: String { get }
        var image: MentionImage? { get }
        var isSelfMention: Bool { get }
    }

    public struct MentionSuggestion: MentionItem {
        public var mentionIdentifier: String
        public var name: String
        public var image: MentionImage?
        public var isSelfMention: Bool

        public init(mentionIdentifier: String? = nil, name: String, image: MentionImage? = nil, isSelfMention: Bool = false) {
            self.mentionIdentifier = mentionIdentifier ?? name
            self.name = name
            self.image = image
            self.isSelfMention = isSelfMention
        }
    }

    public struct MentionConfiguration {
        public var suggestions: [any MentionItem]
        public var selfMentionLabel: String
        public var mentionForegroundColor: UIColor
        public var mentionBackgroundColor: UIColor
        public var otherMentionForegroundColor: UIColor
        public var otherMentionBackgroundColor: UIColor
        public var mentionHorizontalPadding: CGFloat
        public var mentionVerticalPadding: CGFloat
        public var mentionCornerRadius: CGFloat
        public var suggestionForegroundColor: UIColor
        public var suggestionBackgroundColor: UIColor
        public var initialsBackgroundColors: [UIColor]
        public var imageShape: MentionImageShape
        public var imageSize: CGFloat
        public var rowHeight: CGFloat
        public var showsAlphabeticalSections: Bool
        public var sectionHeaderHeight: CGFloat
        public var sectionHeaderForegroundColor: UIColor
        public var sectionHeaderBackgroundColor: UIColor
        public var maximumVisibleRows: Int
        public var listWidth: CGFloat
        public var cornerRadius: CGFloat
        public var exportFormat: MentionExportFormat
        public var loadingText: String

        public init(
            suggestions: [any MentionItem] = [
                MentionSuggestion(name: "Alice"),
                MentionSuggestion(name: "Bob"),
                MentionSuggestion(name: "Charlie"),
                MentionSuggestion(name: "David"),
                MentionSuggestion(name: "Emma"),
                MentionSuggestion(name: "Nikhil", isSelfMention: true)
            ],
            selfMentionLabel: String = "You",
            mentionForegroundColor: UIColor = .white,
            mentionBackgroundColor: UIColor = .systemBlue,
            otherMentionForegroundColor: UIColor = .label,
            otherMentionBackgroundColor: UIColor = .systemGray5,
            mentionHorizontalPadding: CGFloat = 6,
            mentionVerticalPadding: CGFloat = 2,
            mentionCornerRadius: CGFloat = 6,
            suggestionForegroundColor: UIColor = .label,
            suggestionBackgroundColor: UIColor = .secondarySystemBackground,
            initialsBackgroundColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPink, .systemPurple, .systemTeal],
            imageShape: MentionImageShape = .circle,
            imageSize: CGFloat = 44,
            rowHeight: CGFloat = 56,
            showsAlphabeticalSections: Bool = true,
            sectionHeaderHeight: CGFloat = 28,
            sectionHeaderForegroundColor: UIColor = .secondaryLabel,
            sectionHeaderBackgroundColor: UIColor = .tertiarySystemBackground,
            maximumVisibleRows: Int = 4,
            listWidth: CGFloat = 280,
            cornerRadius: CGFloat = 10,
            exportFormat: MentionExportFormat = .anchor,
            loadingText: String = "Loading..."
        ) {
            self.suggestions = suggestions
            self.selfMentionLabel = selfMentionLabel
            self.mentionForegroundColor = mentionForegroundColor
            self.mentionBackgroundColor = mentionBackgroundColor
            self.otherMentionForegroundColor = otherMentionForegroundColor
            self.otherMentionBackgroundColor = otherMentionBackgroundColor
            self.mentionHorizontalPadding = mentionHorizontalPadding
            self.mentionVerticalPadding = mentionVerticalPadding
            self.mentionCornerRadius = mentionCornerRadius
            self.suggestionForegroundColor = suggestionForegroundColor
            self.suggestionBackgroundColor = suggestionBackgroundColor
            self.initialsBackgroundColors = initialsBackgroundColors
            self.imageShape = imageShape
            self.imageSize = imageSize
            self.rowHeight = rowHeight
            self.showsAlphabeticalSections = showsAlphabeticalSections
            self.sectionHeaderHeight = sectionHeaderHeight
            self.sectionHeaderForegroundColor = sectionHeaderForegroundColor
            self.sectionHeaderBackgroundColor = sectionHeaderBackgroundColor
            self.maximumVisibleRows = maximumVisibleRows
            self.listWidth = listWidth
            self.cornerRadius = cornerRadius
            self.exportFormat = exportFormat
            self.loadingText = loadingText
        }
    }

    public struct ToolbarColor {
        public var name: String
        public var color: UIColor

        public init(name: String, color: UIColor) {
            self.name = name
            self.color = color
        }
    }

    public struct ToolbarAction {
        public var title: String
        public var imageName: String?
        public var handler: () -> Void

        public init(title: String, imageName: String? = nil, handler: @escaping () -> Void) {
            self.title = title
            self.imageName = imageName
            self.handler = handler
        }
    }

    public enum PlusButtonBehavior {
        case action(ToolbarAction)
        case menu([ToolbarAction])
    }

    public struct ToolbarConfiguration {
        public var showsModeControl: Bool
        public var plusButtonBehavior: PlusButtonBehavior?
        public var foregroundColors: [ToolbarColor]
        public var backgroundColors: [ToolbarColor]

        public init(
            showsModeControl: Bool = false,
            plusButtonBehavior: PlusButtonBehavior? = nil,
            foregroundColors: [ToolbarColor] = [
                ToolbarColor(name: "Default", color: .label),
                ToolbarColor(name: "Red", color: .systemRed),
                ToolbarColor(name: "Blue", color: .systemBlue),
                ToolbarColor(name: "Green", color: .systemGreen),
                ToolbarColor(name: "Orange", color: .systemOrange),
                ToolbarColor(name: "Purple", color: .systemPurple)
            ],
            backgroundColors: [ToolbarColor] = [
                ToolbarColor(name: "Yellow", color: .systemYellow.withAlphaComponent(0.45)),
                ToolbarColor(name: "Green", color: .systemGreen.withAlphaComponent(0.35)),
                ToolbarColor(name: "Blue", color: .systemBlue.withAlphaComponent(0.3)),
                ToolbarColor(name: "Pink", color: .systemPink.withAlphaComponent(0.3))
            ]
        ) {
            self.showsModeControl = showsModeControl
            self.plusButtonBehavior = plusButtonBehavior
            self.foregroundColors = foregroundColors
            self.backgroundColors = backgroundColors
        }
    }

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
            configureToolbar()
        }
    }

    public var onMentionQueryChanged: ((String?) -> Void)?
    public var onMentionInserted: ((any MentionItem) -> Void)?
    public var onMentionRemoved: ((any MentionItem) -> Void)?
    public private(set) var insertedMentions: [any MentionItem] = []

    public var html: String {
        htmlString()
    }

    public var attributedContent: NSAttributedString {
        editorTextView.attributedText
    }

    public var markdown: String {
        attributedStringToMarkdown(editorTextView.attributedText)
    }

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

    enum ToolbarOption {
        case textStyle
        case bold
        case italic
        case underline
        case strikeThrough
        case baseline
        case clear
        case alignment
        case lists
        case links
        case colors
        case undoRedo
    }

    private let richTextToolbarOptions: [ToolbarOption] = [
        .textStyle, .bold, .italic, .underline, .strikeThrough, .baseline, .clear,
        .alignment, .lists, .links, .colors, .undoRedo
    ]

    private let markdownToolbarOptions: [ToolbarOption] = [
        .bold, .italic, .underline, .strikeThrough, .clear,
        .lists, .links, .undoRedo
    ]

    private let editorTextView = UITextView()
    private let htmlTextView = UITextView()
    private let toolbarScrollView = UIScrollView()
    private let toolbarStackView = UIStackView()
    private let modeControl = UISegmentedControl(items: ["Edit", "HTML"])
    private let placeholderLabel = UILabel()
    private let mentionTableView = UITableView(frame: .zero, style: .plain)

    private typealias MentionSection = (title: String?, suggestions: [any MentionItem])

    private var filteredMentions: [any MentionItem] = []
    private var mentionSections: [MentionSection] = []
    private var mentionQueryRange: NSRange?
    private var remoteMentionSuggestions: [any MentionItem] = []
    private var isMentionSuggestionsLoading = false
    private var lastMentionQuery: String?
    private var mentionQueryTask: Task<Void, Never>?
    private let mentionImageCache = NSCache<NSURL, UIImage>()
    private var editorMode: EditorMode = .richText
    private var listMode: ListMode = .none
    private var orderedListCounter = 1
    private var selectedHeadingStyle: HeadingStyle = .paragraph
    private var isSyncingText = false
    private var toolbarButtons: [ToolbarItem: UIButton] = [:]
    private weak var listsMenuButton: UIButton?

    private let baseFont = UIFont.preferredFont(forTextStyle: .body)
    private let linkColor = UIColor.systemBlue

    private var activeTextView: UITextView {
        editorMode == .richText ? editorTextView : htmlTextView
    }

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
        guard onMentionQueryChanged != nil, mentionQueryRange != nil else { return }
        remoteMentionSuggestions = uniqueMentionSuggestions(items)
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
        configureMentionTableView()

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
        mentionTableView.rowHeight = max(1, mentionConfiguration.rowHeight)
        mentionTableView.sectionHeaderHeight = mentionConfiguration.showsAlphabeticalSections ? max(1, mentionConfiguration.sectionHeaderHeight) : 0
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

        if let plusButtonBehavior = toolbarConfiguration.plusButtonBehavior {
            addPlusButton(behavior: plusButtonBehavior)
            toolbarStackView.addArrangedSubview(separator())
        }

        addToolbarMenuButton(title: "Mode", imageName: "square.2.stack.3d", menu: modeSelectionMenu())
        toolbarStackView.addArrangedSubview(separator())

        let toolbarOptions = editorMode == .richText ? richTextToolbarOptions : markdownToolbarOptions
        var separatorIndex = 0

        for option in toolbarOptions {
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
            }

            separatorIndex += 1
            if separatorIndex == 6 {
                toolbarStackView.addArrangedSubview(separator())
                separatorIndex = 0
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
        htmlTextView.textColor = .label
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

    func addToolbarMenuButton(title: String, imageName: String, menu: UIMenu) -> UIButton {
        var configuration = UIButton.Configuration.bordered()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .label
        configuration.image = UIImage(systemName: imageName)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        let button = UIButton(configuration: configuration)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.accessibilityLabel = title
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        toolbarStackView.addArrangedSubview(button)
        return button
    }

    func addPlusButton(behavior: PlusButtonBehavior) {
        switch behavior {
        case .action(let action):
            addToolbarActionButton(title: action.title, imageName: "plus", handler: action.handler)
        case .menu(let actions):
            addToolbarMenuButton(title: "More Actions", imageName: "plus", menu: externalActionsMenu(actions: actions))
        }
    }

    func addToolbarActionButton(title: String, imageName: String, handler: @escaping () -> Void) {
        var configuration = UIButton.Configuration.bordered()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .label
        configuration.image = UIImage(systemName: imageName)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        let action = UIAction { _ in handler() }
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.accessibilityLabel = title
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
        var richTextAction = UIAction(title: "Rich Text", image: UIImage(systemName: "text.justify")) { [weak self] _ in
            self?.syncHTMLToEditor()
            self?.setMode(.richText)
            self?.configureToolbar()
        }
        var markdownAction = UIAction(title: "Markdown", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [weak self] _ in
            self?.htmlTextView.text = self?.htmlString() ?? ""
            self?.htmlTextView.textColor = .label
            self?.setMode(.html)
            self?.configureToolbar()
        }

        if editorMode == .richText {
            richTextAction.attributes.insert(.disabled)
            richTextAction.state = .on
        } else {
            markdownAction.attributes.insert(.disabled)
            markdownAction.state = .on
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
        hideMentionSuggestions()
        editorTextView.isHidden = mode != .richText
        htmlTextView.isHidden = mode != .html
        if mode == .richText {
            editorTextView.becomeFirstResponder()
        } else {
            htmlTextView.becomeFirstResponder()
        }
    }

    private func applyFormattingInBothModes(_ formattingBlock: @escaping () -> Void) {
        if editorMode == .html {
            syncHTMLToEditor()
        }
        formattingBlock()
        if editorMode == .html {
            htmlTextView.text = htmlString()
        }
    }

    @objc func toggleBold() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleFontTrait(.traitBold)
        }
    }

    @objc func toggleItalic() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleFontTrait(.traitItalic)
        }
    }

    @objc func toggleUnderlineStyle() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleAttribute(.underlineStyle, enabledValue: NSUnderlineStyle.single.rawValue)
        }
    }

    @objc func toggleStrikeThroughStyle() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleAttribute(.strikethroughStyle, enabledValue: NSUnderlineStyle.single.rawValue)
        }
    }

    @objc func toggleSubscript() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleExclusiveBaseline(offset: -5)
        }
    }

    @objc func toggleSuperscript() {
        applyFormattingInBothModes { [weak self] in
            self?.toggleExclusiveBaseline(offset: 5)
        }
    }

    @objc func removeFormatting() {
        applyFormattingInBothModes { [weak self] in
            guard let self else { return }
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
        applyFormattingInBothModes { [weak self] in
            guard let self else { return }
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
    }

    @objc func toggleOrderedList() {
        applyFormattingInBothModes { [weak self] in
            guard let self else { return }
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
    }

    @objc func indentSelection() {
        applyFormattingInBothModes { [weak self] in
            self?.updateParagraphStyle { style in
                style.firstLineHeadIndent += 24
                style.headIndent += 24
            }
        }
    }

    @objc func outdentSelection() {
        applyFormattingInBothModes { [weak self] in
            self?.updateParagraphStyle { style in
                style.firstLineHeadIndent = max(0, style.firstLineHeadIndent - 24)
                style.headIndent = max(0, style.headIndent - 24)
            }
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

            self.applyFormattingInBothModes { [weak self] in
                guard let self else { return }
                let title = displayText.isEmpty ? url.absoluteString : displayText
                editorTextView.selectedRange = selectedRange
                let attributes = linkTypingAttributes(url: url)
                replaceSelection(with: NSAttributedString(string: title, attributes: attributes), selectedOffset: title.utf16.count)
            }
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
        applyFormattingInBothModes { [weak self] in
            guard let self else { return }
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

        let location = selection.location == 0 ? 0 : min(selection.location - 1, textLength - 1)
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
                html += exportedMentionHTML(for: mention)
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

    func exportedMentionHTML(for mention: any MentionItem) -> String {
        let escapedName = escapedHTMLText(mention.name)
        let escapedIdentifier = escapedHTMLAttribute(mention.mentionIdentifier)
        switch mentionConfiguration.exportFormat {
        case .anchor:
            return "<a class=\"mention\" data-mention-id=\"\(escapedIdentifier)\">@\(escapedName)</a>"
        case .custom(let formatter):
            return formatter(mention, escapedName, escapedIdentifier)
        }
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
        refreshInsertedMentions()
    }

    func linkTypingAttributes(url: URL) -> [NSAttributedString.Key: Any] {
        var attributes = defaultTypingAttributes()
        attributes[.link] = url
        attributes[.foregroundColor] = linkColor
        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        return attributes
    }

    func attributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        var markdown = ""
        var index = 0
        let attributedText = attributedString

        while index < attributedText.length {
            var effectiveRange = NSRange(location: 0, length: 0)

            if let mention = attributedText.attribute(.zssMentionItem, at: index, effectiveRange: &effectiveRange) as? any MentionItem {
                markdown += "@\(mention.name)"
            } else if attributedText.attribute(.attachment, at: index, effectiveRange: &effectiveRange) is NSTextAttachment {
                markdown += "[image]"
            } else {
                let text = attributedText.attributedSubstring(from: effectiveRange).string
                var formattedText = text

                if let font = attributedText.attribute(.font, at: index, effectiveRange: nil) as? UIFont {
                    let traits = font.fontDescriptor.symbolicTraits
                    if traits.contains(.traitBold) {
                        formattedText = "**\(formattedText)**"
                    }
                    if traits.contains(.traitItalic) {
                        formattedText = "*\(formattedText)*"
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

                markdown += formattedText
            }
            index = effectiveRange.upperBound
        }

        return markdown
    }

    func updatePlaceholder() {
        placeholderLabel.isHidden = !editorTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateMentionSuggestions() {
        guard let queryRange = activeMentionQueryRange() else {
            endMentionSession()
            return
        }

        let query = String((editorTextView.text as NSString).substring(with: queryRange)
            .dropFirst()
        )
        mentionQueryRange = queryRange

        if onMentionQueryChanged != nil {
            if lastMentionQuery != query {
                scheduleMentionQueryChanged(query)
            }
            filteredMentions = remoteMentionSuggestions
            mentionSections = makeMentionSections(from: filteredMentions)
            showMentionSuggestionsIfNeeded()
            return
        }

        let lowercaseQuery = query.lowercased()
        filteredMentions = allMentionSuggestions()
            .filter { lowercaseQuery.isEmpty || $0.name.lowercased().hasPrefix(lowercaseQuery) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    func isSelfMention(_ suggestion: any MentionItem) -> Bool {
        suggestion.isSelfMention
    }

    private func makeMentionSections(from suggestions: [any MentionItem]) -> [MentionSection] {
        guard mentionConfiguration.showsAlphabeticalSections else {
            return [(title: nil, suggestions: suggestions)]
        }

        let grouped = Dictionary(grouping: suggestions) { suggestion in
            guard let firstCharacter = suggestion.name.first, firstCharacter.isLetter else { return "#" }
            return String(firstCharacter).uppercased()
        }
        return grouped.keys.sorted().map { title in
            (title: title, suggestions: grouped[title] ?? [])
        }
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
        let visibleSectionCount = mentionConfiguration.showsAlphabeticalSections ? min(mentionSections.count, visibleRows) : 0
        let desiredHeight = (CGFloat(visibleRows) * mentionTableView.rowHeight)
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

        let prefixRange = NSRange(location: 0, length: selection.location)
        let expression = try? NSRegularExpression(pattern: #"(?<!\S)@[A-Za-z0-9_]*$"#)
        return expression?.firstMatch(in: editorTextView.text, range: prefixRange)?.range
    }

    func hideMentionSuggestions(endingSession: Bool = true, preservesQuery: Bool = false) {
        if !preservesQuery {
            mentionQueryRange = nil
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
    }

    func mentionSuggestion(at indexPath: IndexPath) -> (any MentionItem)? {
        guard indexPath.section < mentionSections.count else { return nil }
        let suggestions = mentionSections[indexPath.section].suggestions
        guard indexPath.row < suggestions.count else { return nil }
        return suggestions[indexPath.row]
    }

    func mentionImage(for suggestion: any MentionItem) -> UIImage {
        switch suggestion.image {
        case .uiImage(let image):
            return image
        case .initials(let initials):
            return initialsImage(initials, colorSeed: suggestion.name)
        case .url(let url):
            return mentionImageCache.object(forKey: url as NSURL) ?? initialsImage(initials(for: suggestion.name), colorSeed: suggestion.name)
        case nil:
            return initialsImage(initials(for: suggestion.name), colorSeed: suggestion.name)
        }
    }

    func loadMentionImage(for suggestion: any MentionItem, at indexPath: IndexPath) {
        guard case .url(let url) = suggestion.image, mentionImageCache.object(forKey: url as NSURL) == nil else { return }

        Task { [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return }
            mentionImageCache.setObject(image, forKey: url as NSURL)
            guard mentionSuggestion(at: indexPath)?.mentionIdentifier == suggestion.mentionIdentifier else { return }
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

    func mentionPillAttachment(for suggestion: any MentionItem) -> NSTextAttachment {
        let isSelf = isSelfMention(suggestion)
        let foregroundColor = isSelf ? mentionConfiguration.mentionForegroundColor : mentionConfiguration.otherMentionForegroundColor
        let backgroundColor = isSelf ? mentionConfiguration.mentionBackgroundColor : mentionConfiguration.otherMentionBackgroundColor
        let font = editorTextView.typingAttributes[.font] as? UIFont ?? baseFont
        let horizontalPadding = max(0, mentionConfiguration.mentionHorizontalPadding)
        let verticalPadding = max(0, mentionConfiguration.mentionVerticalPadding)
        let text = suggestion.name as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foregroundColor]
        let textSize = text.size(withAttributes: attributes)
        let size = CGSize(width: ceil(textSize.width + (horizontalPadding * 2)), height: ceil(textSize.height + (verticalPadding * 2)))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            backgroundColor.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: max(0, mentionConfiguration.mentionCornerRadius)).fill()
            text.draw(at: CGPoint(x: horizontalPadding, y: verticalPadding), withAttributes: attributes)
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: font.descender - verticalPadding, width: size.width, height: size.height)
        return attachment
    }

    func insertMention(_ suggestion: any MentionItem) {
        guard let queryRange = mentionQueryRange else { return }

        var trailingAttributes = editorTextView.typingAttributes
        trailingAttributes.removeValue(forKey: .backgroundColor)
        trailingAttributes[.foregroundColor] = UIColor.label

        let replacement = NSMutableAttributedString(attachment: mentionPillAttachment(for: suggestion))
        replacement.addAttribute(.zssMentionItem, value: suggestion, range: NSRange(location: 0, length: replacement.length))
        replacement.append(NSAttributedString(string: " ", attributes: trailingAttributes))

        let mutableText = NSMutableAttributedString(attributedString: editorTextView.attributedText)
        mutableText.replaceCharacters(in: queryRange, with: replacement)
        editorTextView.attributedText = mutableText
        editorTextView.selectedRange = NSRange(location: queryRange.location + replacement.length, length: 0)
        editorTextView.typingAttributes = trailingAttributes
        endMentionSession()
        updatePlaceholder()
        updateToolbarSelectionState()
        refreshInsertedMentions()
        onMentionInserted?(suggestion)
    }

    func refreshInsertedMentions() {
        let previousMentions = insertedMentions
        let currentMentions = currentMentionItems()
        insertedMentions = currentMentions

        var currentCounts = Dictionary(currentMentions.map { ($0.mentionIdentifier, 1) }, uniquingKeysWith: +)
        for mention in previousMentions {
            let remainingCount = currentCounts[mention.mentionIdentifier] ?? 0
            if remainingCount > 0 {
                currentCounts[mention.mentionIdentifier] = remainingCount - 1
            } else {
                onMentionRemoved?(mention)
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
            refreshInsertedMentions()
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
        return mentionSections[section].suggestions.count
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isMentionSuggestionsLoading else { return nil }
        guard let title = mentionSections[section].title else { return nil }

        let headerView = UIView()
        headerView.backgroundColor = mentionConfiguration.sectionHeaderBackgroundColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = mentionConfiguration.sectionHeaderForegroundColor
        headerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
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

        guard let suggestion = mentionSuggestion(at: indexPath) else { return cell }
        var configuration = cell.defaultContentConfiguration()
        configuration.text = suggestion.name
        configuration.textProperties.color = mentionConfiguration.suggestionForegroundColor
        if isSelfMention(suggestion) {
            configuration.secondaryText = mentionConfiguration.selfMentionLabel
            configuration.secondaryTextProperties.color = mentionConfiguration.sectionHeaderForegroundColor
        }
        configuration.image = mentionImage(for: suggestion)
        let imageSize = max(1, mentionConfiguration.imageSize)
        configuration.imageProperties.maximumSize = CGSize(width: imageSize, height: imageSize)
        configuration.imageProperties.cornerRadius = imageCornerRadius()
        cell.contentConfiguration = configuration
        cell.backgroundColor = mentionConfiguration.suggestionBackgroundColor
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero
        cell.selectionStyle = .default
        cell.separatorInset = mentionSections[indexPath.section].suggestions.count == 1
            ? UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
            : .zero
        loadMentionImage(for: suggestion, at: indexPath)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isMentionSuggestionsLoading else { return }
        guard let suggestion = mentionSuggestion(at: indexPath) else { return }
        insertMention(suggestion)
    }
}

private extension NSAttributedString.Key {
    static let zssMentionItem = NSAttributedString.Key("com.zssinspirededitor.mentionItem")
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
