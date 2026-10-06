// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CalmChat",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CalmChat", targets: ["CalmChat"])],
    targets: [
        .target(name: "CalmChatCore"),
        .executableTarget(name: "CalmChat", dependencies: ["CalmChatCore"]),
        .testTarget(name: "CalmChatCoreTests", dependencies: ["CalmChatCore"])
    ]
)
