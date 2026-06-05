// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZSSEditorKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ZSSEditorKit",
            targets: ["ZSSEditorKit"]
        )
    ],
    targets: [
        .target(
            name: "ZSSEditorKit",
            path: "ZSSInspiredEditor/ZSSEditorKit/Sources/ZSSEditorKit"
        )
    ]
)
