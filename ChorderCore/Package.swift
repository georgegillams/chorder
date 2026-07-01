// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChorderCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ChorderCore", targets: ["ChorderCore"]),
    ],
    targets: [
        .target(name: "ChorderCore"),
        .testTarget(name: "ChorderCoreTests", dependencies: ["ChorderCore"]),
    ]
)
