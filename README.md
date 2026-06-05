# ZSSEditorKit

`ZSSEditorKit` is a UIKit rich-text editor view controller for iOS. It includes
a horizontally scrolling formatting toolbar, rich-text and HTML editing modes,
lists, links, text alignment, colors, headings, undo/redo, and basic image and
horizontal-rule insertion.

## Requirements

- iOS 15.0 or later
- Swift 5.9 or later
- UIKit

## Integration

The reusable package is located at:

```text
ZSSInspiredEditor/ZSSEditorKit
```

### Swift Package Manager

1. Copy the `ZSSInspiredEditor/ZSSEditorKit` directory into your project or a
   shared location.
2. In Xcode, select **File > Add Package Dependencies**.
3. Select **Add Local...** and choose the copied `ZSSEditorKit` directory.
4. Add the `ZSSEditorKit` library product to your app target.

To publish the package for remote Swift Package Manager installation, place the
contents of `ZSSInspiredEditor/ZSSEditorKit` at the root of its own Git
repository and add that repository's URL as a package dependency.

### CocoaPods

Reference the package directory from your app's `Podfile`:

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  pod 'ZSSEditorKit', path: '../ZSSInspiredEditor/ZSSEditorKit'
end
```

Then install the dependency:

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
- Paragraph and H1-H6 heading styles
- Left, center, right, and justified alignment
- Ordered and unordered lists
- Indent and outdent
- Links and link removal
- Foreground and background colors
- Undo and redo
- Rich-text and HTML editing modes
- Image placeholders and horizontal rules

## Current API

The public API currently provides `RichTextEditorViewController` initialization
and presentation. Editor content configuration and retrieval are not yet
exposed as public APIs.

