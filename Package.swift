// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommandExecutor",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "CommandExecutor",
            targets: ["CommandExecutor"])
    ],
    targets: [
        .target(
            name: "CommandExecutor",
            path: "Sources",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
