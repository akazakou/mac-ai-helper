// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAIHelper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.2"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        // Library target containing all business logic, views, models, and services.
        // Separated from the executable so it can be imported by tests.
        .target(
            name: "MacAIHelperLib",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/MacAIHelperLib"
        ),
        // Thin executable target — only the @main entry point.
        // Resources (e.g. menubar-icon.png) are copied into the app bundle by the Makefile,
        // so no SPM resource processing is needed.
        .executableTarget(
            name: "MacAIHelper",
            dependencies: [
                "MacAIHelperLib",
            ],
            path: "Sources/MacAIHelper"
        ),
        .testTarget(
            name: "MacAIHelperTests",
            dependencies: ["MacAIHelperLib"],
            path: "Tests/MacAIHelperTests"
        ),
    ]
)
