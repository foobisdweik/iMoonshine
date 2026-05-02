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
        .library(
            name: "iMoonshineIntents",
            targets: ["iMoonshineIntents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/moonshine-ai/moonshine-swift.git", from: "0.0.56"),
    ],
    targets: [
        // Shared library: intents, activity attributes, recording state.
        // Imported by the main app, widget extension, and intents extension.
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
        // AppIntents extension target — thin entry point, imports iMoonshineCore.
        .target(
            name: "iMoonshineIntents",
            dependencies: ["iMoonshineCore"],
            path: "Sources/iMoonshineIntents"
        ),
    ]
)
