// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AuthModule",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AuthModule",
            targets: ["AuthModule"]
        ),
    ],
    dependencies: [
        .package(path: "../Network"),
    ],
    targets: [
        .target(
            name: "AuthModule",
            dependencies: [
                "Network",
            ]
        ),
        .testTarget(
            name: "AuthModuleTests",
            dependencies: [
                "AuthModule",
            ]
        ),
    ]
)
