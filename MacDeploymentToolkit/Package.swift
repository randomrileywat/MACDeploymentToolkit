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
            path: ".",
            sources: [
                "MacDeploymentToolkitApp.swift",
                "Models/ApplicationDefinition.swift",
                "Models/ApplicationCatalog.swift",
                "Views/ContentView.swift",
                "Services/DeploymentManager.swift",
                "Services/NetworkMonitor.swift",
                "Services/HomebrewInstaller.swift",
                "Services/DirectDownloadInstaller.swift",
                "Services/SystemStandardizer.swift"
            ]
        )
    ]
)
