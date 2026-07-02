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
- Paragraph and H1–H6 heading styles
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

## License

MIT
