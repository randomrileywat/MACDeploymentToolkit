//
//  MacDeploymentToolkitApp.swift
//  MacDeploymentToolkit
//
//  Diversified Mac Deployment Toolkit
//  A macOS port of the PC Deployment Toolkit for AV Production engineering workstations
//
//  Created by Riley Watson with Diversified Engineering
//

import SwiftUI

@main
struct MacDeploymentToolkitApp: App {
    @StateObject private var deploymentManager = DeploymentManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var catalogStore = CatalogStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deploymentManager)
                .environmentObject(networkMonitor)
                .environmentObject(catalogStore)
        }
        .windowResizabilityContentSize()
    }
}

// MARK: - Window Resizability for macOS 11+ compatibility

extension Scene {
    /// Constrains the window to fit its content size, preventing extra padding/black bars
    func windowResizabilityContentSize() -> some Scene {
        if #available(macOS 13.0, *) {
            return self.defaultSize(width: 700, height: 680)
        } else {
            return self
        }
    }
}
