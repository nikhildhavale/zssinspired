import UIKit

// Public configuration and model types for RichTextEditorViewController,
// plus the internal toolbar/editing enums, split out of the main file.
extension RichTextEditorViewController {

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

    /// The character that starts a mention session. Both "@" mentions and
    /// "#" hashtags render as a bare-name pill in the editor — neither
    /// includes the trigger symbol as visible text; `symbol` is used for
    /// export (HTML/markdown) and to tell sessions apart, not for display.
    public enum MentionTrigger: Character, CaseIterable {
        case at = "@"
        case hash = "#"

        public var symbol: String { String(rawValue) }
    }

    /// `mentionDisplayName`/`mentionImage` are named to avoid colliding with
    /// `name`/`image` properties conforming Objective-C classes may already
    /// declare (e.g. an existing `name: NSString!` can't witness a
    /// non-optional `name: String` requirement).
    public protocol MentionItem {
        /// Opaque backend/dedup key. Never shown to the user — don't wire a
        /// username or handle in here expecting it to render; use
        /// `mentionDisplayName` for anything user-visible.
        var mentionIdentifier: String { get }
        /// The exact text rendered everywhere this mention appears: the
        /// suggestion row AND the pill inserted into the editor. Must be the
        /// human-readable name (e.g. "Nikhil Dhavale"), never a username,
        /// handle, or identifier — the two are easy to conflate when a host
        /// model only exposes one "name"-ish field, so double check this
        /// isn't accidentally wired to a login/username property.
        var mentionDisplayName: String { get }
        var mentionImage: MentionImage? { get }
        var isSelfMention: Bool { get }
        /// Whether this mention represents a team/group rather than a
        /// person — drives whether it's grouped under the "People" or
        /// "Team" suggestion section.
        var isTeamMention: Bool { get }
    }

    public struct MentionSuggestion: MentionItem {
        public var mentionIdentifier: String
        public var mentionDisplayName: String
        public var mentionImage: MentionImage?
        public var isSelfMention: Bool
        public var isTeamMention: Bool

        /// - Parameter displayName: The human-readable name to render — not a
        ///   username/handle. Also used as `mentionIdentifier` when
        ///   `mentionIdentifier` is omitted, so pass a stable backend key
        ///   there explicitly if this name can change or collide.
        public init(mentionIdentifier: String? = nil, displayName: String, image: MentionImage? = nil, isSelfMention: Bool = false, isTeamMention: Bool = false) {
            self.mentionIdentifier = mentionIdentifier ?? displayName
            self.mentionDisplayName = displayName
            self.mentionImage = image
            self.isSelfMention = isSelfMention
            self.isTeamMention = isTeamMention
        }
    }

    /// A "#" hashtag suggestion. Deliberately separate from `MentionItem`:
    /// hashtags have no avatar or self/other distinction, render as a
    /// colored badge + pill row instead of an avatar + name row, and carry
    /// their own display color instead of using `MentionConfiguration`'s
    /// foreground/background colors.
    public protocol HashtagItem {
        var hashtagIdentifier: String { get }
        var hashtagDisplayName: String { get }
        /// Falls back to `.label` wherever a hashtag is rendered if `nil`.
        var hashtagColor: UIColor? { get }
    }

    public struct HashtagSuggestion: HashtagItem {
        public var hashtagIdentifier: String
        public var hashtagDisplayName: String
        public var hashtagColor: UIColor?

        public init(hashtagIdentifier: String? = nil, name: String, color: UIColor? = nil) {
            self.hashtagIdentifier = hashtagIdentifier ?? name
            self.hashtagDisplayName = name
            self.hashtagColor = color
        }
    }

    public struct MentionConfiguration {
        /// Characters that open a mention session while typing.
        public var triggers: [MentionTrigger]
        public var suggestions: [any MentionItem]
        /// Local (non-provider) "#" hashtag suggestions, mirroring
        /// `suggestions` for "@" mentions.
        public var hashtagSuggestions: [any HashtagItem]
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
        /// Whether suggestions are grouped under "People"/"Team"/"Hashtags"
        /// section headers, or shown as a single flat list.
        public var showsSuggestionSections: Bool
        public var sectionHeaderHeight: CGFloat
        public var sectionHeaderForegroundColor: UIColor
        public var sectionHeaderBackgroundColor: UIColor
        /// Section header titles, sourced from config so hosts can localize them.
        public var peopleSectionTitle: String
        public var teamSectionTitle: String
        public var hashtagSectionTitle: String
        public var maximumVisibleRows: Int
        public var listWidth: CGFloat
        public var cornerRadius: CGFloat
        public var exportFormat: MentionExportFormat
        public var loadingText: String
        /// Side length of the "#" badge shown to the left of each hashtag pill.
        public var hashtagBadgeSize: CGFloat
        public var hashtagBadgeBackgroundColor: UIColor
        public var hashtagBadgeForegroundColor: UIColor

        public init(
            triggers: [MentionTrigger] = [.at, .hash],
            suggestions: [any MentionItem] = [
                MentionSuggestion(displayName: "Alice"),
                MentionSuggestion(displayName: "Bob"),
                MentionSuggestion(displayName: "Charlie"),
                MentionSuggestion(displayName: "David"),
                MentionSuggestion(displayName: "Emma"),
                MentionSuggestion(displayName: "Nikhil", isSelfMention: true)
            ],
            hashtagSuggestions: [any HashtagItem] = [],
            selfMentionLabel: String = "You",
            mentionForegroundColor: UIColor = .white,
            mentionBackgroundColor: UIColor = .systemBlue,
            otherMentionForegroundColor: UIColor = .label,
            otherMentionBackgroundColor: UIColor = .systemGray5,
            mentionHorizontalPadding: CGFloat = 6,
            mentionVerticalPadding: CGFloat = 2,
            mentionCornerRadius: CGFloat = 6,
            suggestionForegroundColor: UIColor = .label,
            suggestionBackgroundColor: UIColor = .systemBackground,
            initialsBackgroundColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPink, .systemPurple, .systemTeal],
            imageShape: MentionImageShape = .circle,
            imageSize: CGFloat = 44,
            rowHeight: CGFloat = 56,
            showsSuggestionSections: Bool = true,
            sectionHeaderHeight: CGFloat = 28,
            sectionHeaderForegroundColor: UIColor = .secondaryLabel,
            sectionHeaderBackgroundColor: UIColor = .tertiarySystemBackground,
            peopleSectionTitle: String = "People",
            teamSectionTitle: String = "Teams",
            hashtagSectionTitle: String = "Hashtags",
            maximumVisibleRows: Int = 4,
            listWidth: CGFloat = 280,
            cornerRadius: CGFloat = 10,
            exportFormat: MentionExportFormat = .anchor,
            loadingText: String = "Loading...",
            hashtagBadgeSize: CGFloat = 32,
            hashtagBadgeBackgroundColor: UIColor = .systemGray5,
            hashtagBadgeForegroundColor: UIColor = .secondaryLabel
        ) {
            self.triggers = triggers
            self.suggestions = suggestions
            self.hashtagSuggestions = hashtagSuggestions
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
            self.showsSuggestionSections = showsSuggestionSections
            self.sectionHeaderHeight = sectionHeaderHeight
            self.sectionHeaderForegroundColor = sectionHeaderForegroundColor
            self.sectionHeaderBackgroundColor = sectionHeaderBackgroundColor
            self.peopleSectionTitle = peopleSectionTitle
            self.teamSectionTitle = teamSectionTitle
            self.hashtagSectionTitle = hashtagSectionTitle
            self.maximumVisibleRows = maximumVisibleRows
            self.listWidth = listWidth
            self.cornerRadius = cornerRadius
            self.exportFormat = exportFormat
            self.loadingText = loadingText
            self.hashtagBadgeSize = hashtagBadgeSize
            self.hashtagBadgeBackgroundColor = hashtagBadgeBackgroundColor
            self.hashtagBadgeForegroundColor = hashtagBadgeForegroundColor
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

    /// Like `ToolbarAction`, but the handler receives the editor's current
    /// markdown so the host app gets the content directly on the call.
    public struct MarkdownToolbarAction {
        public var title: String
        public var imageName: String?
        public var handler: (_ markdown: String) -> Void

        public init(title: String, imageName: String? = nil, handler: @escaping (_ markdown: String) -> Void) {
            self.title = title
            self.imageName = imageName
            self.handler = handler
        }
    }

    public enum MarkdownPlusButtonBehavior {
        case action(MarkdownToolbarAction)
        case menu([MarkdownToolbarAction])
    }

    public struct ToolbarConfiguration {
        /// The editing mode the toolbar is configured for. Determines which
        /// toolbar options are shown; change it (or call `setContentMode`)
        /// to switch between rich text and markdown.
        public var contentMode: ContentMode
        /// Whether the toolbar shows the Rich Text / Markdown mode switch.
        /// Set to false to lock the editor to `contentMode`.
        public var showsModeControl: Bool
        public var plusButtonBehavior: PlusButtonBehavior?
        /// Plus button behavior used while in markdown mode; its handlers are
        /// passed the editor's current markdown. When nil, markdown mode falls
        /// back to `plusButtonBehavior`.
        public var markdownPlusButtonBehavior: MarkdownPlusButtonBehavior?
        /// Fill color of the plus button in markdown mode.
        public var plusButtonColor: UIColor
        public var foregroundColors: [ToolbarColor]
        public var backgroundColors: [ToolbarColor]
        /// Height of the toolbar row. Defaults to a roomy 58pt; set something
        /// smaller (e.g. 42) to match a more compact design spec.
        public var toolbarHeight: CGFloat
        /// Width and height of each toolbar button, including the plus button.
        /// Defaults to 38pt; set something smaller (e.g. 30) to match a more
        /// compact design spec.
        public var buttonSize: CGFloat

        public init(
            contentMode: ContentMode = .richText,
            showsModeControl: Bool = true,
            plusButtonBehavior: PlusButtonBehavior? = nil,
            markdownPlusButtonBehavior: MarkdownPlusButtonBehavior? = nil,
            plusButtonColor: UIColor = UIColor(red: 0.18, green: 0.55, blue: 0.34, alpha: 1),
            toolbarHeight: CGFloat = 58,
            buttonSize: CGFloat = 38,
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
            self.contentMode = contentMode
            self.showsModeControl = showsModeControl
            self.plusButtonBehavior = plusButtonBehavior
            self.markdownPlusButtonBehavior = markdownPlusButtonBehavior
            self.plusButtonColor = plusButtonColor
            self.toolbarHeight = toolbarHeight
            self.buttonSize = buttonSize
            self.foregroundColors = foregroundColors
            self.backgroundColors = backgroundColors
        }
    }

    enum EditorMode {
        case richText
        case html
    }

    enum ListMode {
        case none
        case unordered
        case ordered
    }

    enum HeadingStyle: String, CaseIterable, Hashable {
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

    enum ToolbarItem: Hashable {
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
        case outdent
        case link
        case removeLink
        case foregroundColor
        case backgroundColor
    }

    public enum ContentMode {
        case richText
        case markdown
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
        case separator
        case bulletList
        case numberedList
        case outdent
        case indent
        case addLink
        case removeLink
    }
}

extension RichTextEditorViewController.MentionItem {
    public var isTeamMention: Bool { false }
}
