---
name: project-design-decisions
description: "How ZSSEditorKit was designed — architecture choices, key patterns, and implementation rationale"
metadata: 
  node_type: memory
  type: project
  originSessionId: 28d007cd-f8f9-453a-93de-00d762eac536
---

## Core Idea

ZSSEditorKit is a UIKit-native rich text editor *inspired by* ZSSRichTextEditor, but built
entirely on `UITextView` + `NSAttributedString` instead of the original's `WKWebView` + JavaScript
approach. The goal was a native, dependency-free drop-in that avoids the WebView bridge overhead
and works cleanly as a Swift package.

**Why not WKWebView like the original ZSS?**
The original ZSSRichTextEditor runs a full HTML document in a web view and calls JS functions to
apply formatting. That approach makes HTML the source of truth but introduces bridge latency,
requires bundled JS/CSS assets, and makes it harder to distribute as a Swift package. The UITextView
approach uses `NSAttributedString` as the source of truth, which integrates directly with UIKit's
undo/redo, text selection, accessibility, and keyboard handling — no JS bridge needed.

## Architecture

Single class: `RichTextEditorViewController : UIViewController, UITextViewDelegate`
No subviews broken into separate files — everything is one file, organized into private extensions by concern:
- View setup (`configureView`, `configureToolbar`, `configureTextViews`)
- Toolbar actions (toggle bold/italic, headings, alignment, lists, etc.)
- Attribute helpers (`applyAttribute`, `removeAttribute`, `toggleAttribute`, `toggleFontTrait`)
- List logic (apply/remove markers, continuation on newline)
- HTML conversion (export via `NSAttributedString` HTML document type, import back)
- `UITextViewDelegate` (newline interception for list continuation)
- `String` extensions (list marker detection via regex)

## Key Design Patterns

### Toolbar state sync
`updateToolbarSelectionState()` is called on every selection change and text change.
It inspects `typingAttributes` (for cursor-only / zero-length selection) OR enumerates
`attributedText` attributes over the selection range to decide button highlight state.
`selectionInspectionRange()` resolves the right range in both cases.

Buttons use `configurationUpdateHandler` (iOS 15+ `UIButton.Configuration`) to swap
foreground/background color when `isSelected` changes — no manual tint juggling.

### Attribute toggling
`toggleAttribute(_:enabledValue:)` checks if the attribute exists at the current
selection location. If absent → apply; if present → remove. Works for both
zero-length selections (updates `typingAttributes`) and ranged selections (mutates
`attributedText` and restores `selectedRange`).

Font traits (bold/italic) go through `toggleFontTrait` which reads the current font's
`UIFontDescriptor.SymbolicTraits`, flips the bit, and reconstructs the font —
preserving size, weight, and other traits.

### Heading styles
Stored as `HeadingStyle` enum with `pointSize` and `isBold` properties.
Applied per-paragraph by enumerating the `.font` attribute and calling `fontMatching(_:pointSize:forceBold:)`
which preserves italic/other traits while overriding size and bold.
Current heading is inferred by matching the current font's point size to the nearest `HeadingStyle`.

### List continuation
Intercepted in `textView(_:shouldChangeTextIn:replacementText:)` when `text == "\n"`.
Checks the previous paragraph's text for a list marker (via `String.listMarkerRange` regex),
injects the next marker, and returns `false` to suppress the default newline.
Empty marker on its own line (just "• " or "1. ") → ends the list and removes the marker.
Uses plain-text prefix matching via regex on `String` extensions rather than storing
list state in attributes.

### HTML mode
Two `UITextView`s overlaid in the same frame — only one visible at a time.
Switching to HTML: serialises `editorTextView.attributedText` via
`NSAttributedString.data(from:documentAttributes:)` with `.html` document type.
Switching back: parses the edited HTML string back into `NSAttributedString` via
the `.html` document type initializer.
This gives round-trip HTML without any custom serialiser.

### Two-mode toolbar (Edit / HTML)
`UISegmentedControl` at the left of the toolbar scroll view.
In HTML mode, all formatting buttons are implicitly inactive (state sync guard
`guard editorMode == .richText` exits early).

## Constraints & Known Gaps (at time of writing)

- No public API for reading/setting content — `editorTextView` is private.
  `RichTextEditorViewController` is intended to be subclassed or extended to expose this.
- `insertLink` hardcodes a placeholder URL (openai.com) — no URL input dialog yet.
- Color pickers use hardcoded colors (systemRed for foreground, systemYellow for background).
- Image insertion is a placeholder attachment — no real image picker.
- List state (`listMode`, `orderedListCounter`) is partially tracked on the controller
  but also inferred from text content, which can drift.

**Why:** How to apply: When adding features, follow the existing pattern of `private extension`
blocks. New toolbar items need an entry in `ToolbarItem` enum, a button registration in
`configureToolbar`, and a handler in `updateToolbarSelectionState`. Content API should be
added as `public` methods/properties directly on `RichTextEditorViewController`.
