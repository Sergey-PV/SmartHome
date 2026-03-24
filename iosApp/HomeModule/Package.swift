// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HomeModule",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HomeModule",
            targets: ["HomeModule"]
        ),
    ],
    dependencies: [
        .package(path: "../AuthModule"),
        .package(path: "../Network"),
    ],
    targets: [
        .target(
            name: "HomeModule",
            dependencies: [
                "AuthModule",
                "Network",
            ]
        ),
        .testTarget(
            name: "HomeModuleTests",
            dependencies: ["HomeModule"]
        ),
    ]
)
