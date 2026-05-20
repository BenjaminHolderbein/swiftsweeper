// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swiftsweeper",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "SwiftSweeper", targets: ["SwiftSweeper"])
    ],
    targets: [
        .target(
            name: "SwiftSweeperKit",
            path: "Sources/SwiftSweeperKit"),
        .executableTarget(
            name: "SwiftSweeper",
            dependencies: ["SwiftSweeperKit"],
            path: "Sources/SwiftSweeper"),
        .testTarget(
            name: "SwiftSweeperKitTests",
            dependencies: ["SwiftSweeperKit"],
            path: "Tests/SwiftSweeperKitTests"),
    ]
)
