// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SelfRefreshKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SelfRefreshKit",
            targets: ["SelfRefreshKit"]
        )
    ],
    targets: [
        .target(
            name: "SelfRefreshKit",
            path: "Sources/SelfRefreshKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SelfRefreshKitTests",
            dependencies: ["SelfRefreshKit"],
            path: "Tests/SelfRefreshKitTests"
        )
    ]
)
