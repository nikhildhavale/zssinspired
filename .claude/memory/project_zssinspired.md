---
name: project-zssinspired
description: "ZSSInspiredEditor project — repo layout, GitHub URL, package integration setup"
metadata: 
  node_type: memory
  type: project
  originSessionId: 28d007cd-f8f9-453a-93de-00d762eac536
---

GitHub repo: https://github.com/nikhildhavale/zssinspired (SSH: git@github.com:nikhildhavale/zssinspired.git)

The repo is both the demo app (ZSSInspiredEditor) and the distributable library (ZSSEditorKit).

**Layout:**
- `ZSSInspiredEditor/` — Xcode app target (UIKit, SceneDelegate-based)
- `ZSSInspiredEditor/ZSSEditorKit/` — local Swift package used by the app target
- `Package.swift` (repo root) — makes the repo consumable as a remote SPM package
- `ZSSEditorKit.podspec` (repo root) — makes the repo consumable via CocoaPods

**Integration for consumers:**

SPM (Package.swift):
```swift
.package(url: "https://github.com/nikhildhavale/zssinspired.git", branch: "main")
```
Product name: `ZSSEditorKit`, package: `zssinspired`

CocoaPods (Podfile):
```ruby
pod 'ZSSEditorKit', :git => 'https://github.com/nikhildhavale/zssinspired.git'
```
No branch needed — CocoaPods defaults to the repo's default branch (main).

**Source files location:** `ZSSInspiredEditor/ZSSEditorKit/Sources/ZSSEditorKit/`
Main class: `RichTextEditorViewController`

**Why:** No git tag versioning — distribution is off the main branch directly.
**How to apply:** When updating the library or integration docs, keep root Package.swift and podspec in sync with the source path. No tags needed unless user decides to version.
