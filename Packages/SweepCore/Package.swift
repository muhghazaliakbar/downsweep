// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SweepCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SweepCore", targets: ["SweepCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
    ],
    targets: [
        .target(
            name: "SweepCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            // Declared explicitly: not every SwiftPM picks up .xcstrings on its own, and without a
            // resource bundle `Bundle.module` doesn't exist.
            resources: [.process("Resources")]
        ),
        .testTarget(name: "SweepCoreTests", dependencies: ["SweepCore"]),
    ]
)
