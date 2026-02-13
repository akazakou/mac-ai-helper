// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAIHelper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacAIHelper",
            path: "Sources/MacAIHelper",
            resources: [
                .copy("Resources/icon.svg"),
            ]
        ),
        .testTarget(
            name: "MacAIHelperTests",
            dependencies: ["MacAIHelper"],
            path: "Tests/MacAIHelperTests"
        ),
    ]
)
