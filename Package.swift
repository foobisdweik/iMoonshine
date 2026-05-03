// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iMoonshine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "iMoonshineCore",
            targets: ["iMoonshineCore"]
        ),
        .library(
            name: "iMoonshine",
            targets: ["iMoonshine"]
        ),
        .library(
            name: "iMoonshineWidget",
            targets: ["iMoonshineWidget"]
        ),
    ],
    dependencies: [
        .package(path: "Vendor/moonshine-swift"),
    ],
    targets: [
        // Shared library: activity attributes and recording state.
        // Imported by the main app and widget extension.
        .target(
            name: "iMoonshineCore",
            dependencies: [
                .product(name: "MoonshineVoice", package: "moonshine-swift"),
            ],
            path: "Sources/iMoonshineCore",
            resources: [
                .copy("Models"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        // Main app target — UI only, imports iMoonshineCore.
        .target(
            name: "iMoonshine",
            dependencies: ["iMoonshineCore"],
            path: "Sources/iMoonshine"
        ),
        // Widget extension target.
        .target(
            name: "iMoonshineWidget",
            dependencies: ["iMoonshineCore"],
            path: "Sources/iMoonshineWidget"
        ),
    ]
)
