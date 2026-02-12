// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAIHelper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacAIHelper",
            path: "Sources/MacAIHelper"
        ),
        .testTarget(
            name: "MacAIHelperTests",
            dependencies: ["MacAIHelper"],
            path: "Tests/MacAIHelperTests"
        ),
    ]
)
