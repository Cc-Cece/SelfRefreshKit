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
    dependencies: [
        .package(url: "https://github.com/SideStore/SideSign.git", branch: "main"),
        .package(url: "https://github.com/mahee96/AnisetteKit.git", branch: "main")
    ],
    targets: [
        .binaryTarget(
            name: "IDevice",
            url: "https://github.com/SideStore/idevice/releases/download/v0.1.68-ss-3e55c84/idevice-xcframework-v0.1.68-ss-3e55c84.zip",
            checksum: "445702d53942597deb4cdec2c4122d16a3f4ac124ce26cd75b68dab3dad92416"
        ),
        .target(
            name: "SelfRefreshKit",
            dependencies: [
                .product(name: "SideSign", package: "SideSign"),
                .product(name: "AnisetteKit", package: "AnisetteKit"),
                "IDevice"
            ],
            path: "Sources/SelfRefreshKit",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("Security"),
                .linkedFramework("Network")
            ]
        ),
        .testTarget(
            name: "SelfRefreshKitTests",
            dependencies: ["SelfRefreshKit"],
            path: "Tests/SelfRefreshKitTests"
        )
    ]
)
