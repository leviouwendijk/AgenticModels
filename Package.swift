// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticModels",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AgenticModels",
            targets: [
                "AgenticModels",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Agentic.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "AgenticModels",
            dependencies: [
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
