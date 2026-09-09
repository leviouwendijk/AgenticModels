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
        .executable(
            name: "amodeltest",
            targets: [
                "AgenticModelsTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Agentic.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
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
        .executableTarget(
            name: "AgenticModelsTestFlows",
            dependencies: [
                "AgenticModels",
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
