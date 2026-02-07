// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AwesomeQuickNote",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AwesomeQuickNote", targets: ["AwesomeQuickNote"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/krisk/fuse-swift", from: "1.4.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "AwesomeQuickNote",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Fuse", package: "fuse-swift"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "AwesomeQuickNote",
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
    ]
)
