// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TouchGuardCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TouchGuardCore", targets: ["TouchGuardCore"]),
    ],
    targets: [
        .target(name: "TouchGuardCore"),
        .testTarget(name: "TouchGuardCoreTests", dependencies: ["TouchGuardCore"]),
    ],
    swiftLanguageModes: [.v6]
)
