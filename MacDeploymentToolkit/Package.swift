// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacDeploymentToolkit",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MacDeploymentToolkit",
            targets: ["MacDeploymentToolkit"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacDeploymentToolkit",
            path: "Sources/MacDeploymentToolkit"
        )
    ]
)
