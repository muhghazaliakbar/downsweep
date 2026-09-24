// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SweepCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SweepCore", targets: ["SweepCore"]),
    ],
    targets: [
        .target(name: "SweepCore"),
        .testTarget(name: "SweepCoreTests", dependencies: ["SweepCore"]),
    ]
)
