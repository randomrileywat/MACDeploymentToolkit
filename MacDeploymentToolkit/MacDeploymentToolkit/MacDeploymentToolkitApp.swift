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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deploymentManager)
                .environmentObject(networkMonitor)
                .frame(width: 700, height: 680)
        }
    }
}
