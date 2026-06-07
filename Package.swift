// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ASCamera",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ASCamera",
            targets: ["ASCamera"]
        )
    ],
    targets: [
        .target(
            name: "ASCamera",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ASCameraTests",
            dependencies: ["ASCamera"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
