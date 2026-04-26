// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DAWSON",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable", .upToNextMajor(from: "0.6.7")),
        .package(url: "https://github.com/stephencelis/SQLite.swift", .upToNextMajor(from: "0.14.1")),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "DAWSON",
            dependencies: [
                // Link AnyCodable to your target
                .product(name: "AnyCodable", package: "AnyCodable"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources"
        ),
    ]
)
