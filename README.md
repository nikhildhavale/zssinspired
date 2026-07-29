# ZSSEditorKit

`ZSSEditorKit` is a UIKit rich-text editor view controller for iOS. It includes
a horizontally scrolling formatting toolbar, rich-text and HTML editing modes,
lists, links, text alignment, colors, headings, undo/redo, and basic image and
horizontal-rule insertion.

## Requirements

- iOS 15.0 or later
- Swift 5.9 or later
- UIKit

## Installation

### Swift Package Manager

In Xcode, select **File > Add Package Dependencies** and enter the repository URL:

```
https://github.com/nikhildhavale/zssinspired
```

Or add it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/nikhildhavale/zssinspired.git", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "ZSSEditorKit", package: "zssinspired")
        ]
    )
]
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  pod 'ZSSEditorKit', :git => 'https://github.com/nikhildhavale/zssinspired.git'
end
```

Then run:

```sh
pod install
```

## Usage

Import the module and present `RichTextEditorViewController`:

```swift
import UIKit
import ZSSEditorKit

final class ViewController: UIViewController {
    @IBAction private func openEditor() {
        let editor = RichTextEditorViewController()
        let navigationController = UINavigationController(
            rootViewController: editor
        )
        present(navigationController, animated: true)
    }
}
```

To use the editor as the root view controller in a UIKit scene:

```swift
import UIKit
import ZSSEditorKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let editor = RichTextEditorViewController()
        window.rootViewController = UINavigationController(
            rootViewController: editor
        )
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

## Available Editing Features

- Bold, italic, underline, and strikethrough
- Subscript and superscript
- Paragraph and H1–H6 heading styles, sized proportionally to the
  configured body font (2x/1.5x/1.25x/1x/0.875x/0.85x), matching the scale
  [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)'s GitHub
  theme uses
- Left, center, right, and justified alignment
- Ordered and unordered lists
- Indent and outdent
- Links and link removal
- Foreground and background colors
- Undo and redo
- Rich-text and HTML editing modes
- Image placeholders and horizontal rules
- Markdown export support

## Markdown Export

Export the attributed string content as Markdown:

```swift
let editor = RichTextEditorViewController()
let markdown = editor.markdown  // Get markdown representation
```

The editor automatically converts formatting (bold, italic, underline, strikethrough, links) to their Markdown equivalents.

In markdown mode, paragraph spacing and list indent are tuned to match how
[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) (used as
the styling reference — not a dependency of this package) spaces the same
content: lines continuing the same list or the same soft-wrapped paragraph
stay tight, while a real block boundary (entering/leaving a list, switching
list type, a heading) gets the larger gap MarkdownUI's GitHub theme gives
sibling blocks — so what you see while editing matches what gets rendered
elsewhere.

## Markdown Preview

Show a read-only preview of how the current content will actually render,
built from the editor's own attributed-string pipeline (the same
block-spacing/indent logic used while editing) rather than pulling in
MarkdownUI or another third-party renderer as a dependency:

```swift
editor.presentMarkdownPreview(markdown: editor.markdown)
```

Not wired to any built-in toolbar button — call it from a host-supplied
action (e.g. a `markdownPlusButtonBehavior` entry) to add a "Preview"
affordance where it makes sense for your app.

## Setting Content, Mode, Placeholder, and Focus

```swift
let editor = RichTextEditorViewController()

// Start in markdown mode (or lock it there with showsModeControl: false).
editor.setContentMode(.markdown)

// Hand off existing content — markdown is converted back to the styled
// attributed string the editor displays in edit mode.
editor.setMarkdown("# Title\n\n**Bold** and [a link](https://example.com)")
editor.setHTML("<b>Bold</b> and <i>italic</i>")  // alternatively, from HTML

editor.placeholder = "Write a comment..."
editor.focus()  // give the editor keyboard focus
editor.blur()   // resign keyboard focus
```

`setMarkdown(_:)` understands the same dialect the `markdown` getter emits: `**bold**`, `*italic*`, `__underline__`, `~~strikethrough~~`, `[text](url)`, `#`–`######` headings, `- ` bullets, `1. ` numbered lists, and 4-space list indents.

## Mentions: `MentionItem`

Types you hand to `MentionConfiguration.suggestions` or return from `MentionSuggestionsProviding` must conform to `MentionItem`:

```swift
public protocol MentionItem {
    var mentionIdentifier: String { get }
    var mentionDisplayName: String { get }
    var mentionImage: RichTextEditorViewController.MentionImage? { get }
    var isSelfMention: Bool { get }
}
```

`mentionDisplayName`/`mentionImage` are deliberately not named `name`/`image` — an Objective-C class conforming to `MentionItem` may already declare its own `name`/`image` property (e.g. an implicitly-unwrapped `NSString!`), which can't witness a non-optional `String` protocol requirement of the same name. Conform via an `extension` on your existing model type rather than adding stored properties where possible.

## License

MIT
