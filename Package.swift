// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "happymode-core-tests",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HappymodeCore",
            targets: ["HappymodeCore"]
        )
    ],
    targets: [
        .target(
            name: "HappymodeCore",
            path: "happymode/Core",
            sources: [
                "Solar/SolarCalculator.swift",
                "Solar/SolarPackage.swift",
                "Theme/ThemeController.swift"
            ]
        ),
        .testTarget(
            name: "HappymodeCoreTests",
            dependencies: ["HappymodeCore"],
            path: "happymodeTests"
        )
    ]
)
