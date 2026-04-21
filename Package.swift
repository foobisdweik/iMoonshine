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
            name: "iMoonshine",
            targets: ["iMoonshine"]
        ),
        .library(
            name: "iMoonshineWidget",
            targets: ["iMoonshineWidget"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/moonshine-ai/moonshine-swift.git", from: "0.0.56"),
    ],
    targets: [
        .target(
            name: "iMoonshine",
            dependencies: [
                .product(name: "MoonshineVoice", package: "moonshine-swift"),
            ],
            resources: [
                .copy("Models"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "iMoonshineWidget",
            path: "Sources/iMoonshineWidget"
        ),
    ]
)
