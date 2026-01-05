//
//  ContentView.swift
//  MacDeploymentToolkit
//
//  Main application view with application selection tree and deployment controls
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var deploymentManager: DeploymentManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    @State private var selectedApps: Set<UUID> = []
    @State private var expandedCategories: Set<ApplicationCategory> = Set(ApplicationCategory.allCases)
    @State private var macStandardizationEnabled = false
    @State private var computerName: String = Host.current().localizedName ?? "Mac"
    @State private var customIconPath: String = ""
    
    private let primaryBlue = Color(red: 0, green: 0.47, blue: 0.83) // #0078D4
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main Content
            if deploymentManager.isDeploying {
                deploymentView
            } else {
                selectionView
            }
        }
        .frame(width: 650, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diversified Mac Deployment Toolkit")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(primaryBlue)
                
                if !deploymentManager.isDeploying {
                    Text("Select applications to install:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Network status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(networkMonitor.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Selection View (Pre-Deployment)
    
    private var selectionView: some View {
        VStack(spacing: 0) {
            // Application Tree View
            applicationTreeView
                .frame(maxHeight: .infinity)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Mac Standardization Section
            macStandardizationSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Bottom Bar with Status and Deploy Button
            bottomBar
        }
    }
    
    // MARK: - Application Tree View
    
    private var applicationTreeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ApplicationCategory.allCases) { category in
                    categorySection(for: category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func categorySection(for category: ApplicationCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Text(category.icon)
                        .font(.system(size: 12))
                    
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Selection count for category
                    let count = selectedCountForCategory(category)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(primaryBlue)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Category Items
            if expandedCategories.contains(category) {
                let apps = ApplicationCatalog.applications(for: category)
                ForEach(apps) { app in
                    applicationRow(for: app)
                }
            }
        }
    }
    
    private func applicationRow(for app: ApplicationDefinition) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { selectedApps.contains(app.id) },
                set: { isSelected in
                    if isSelected {
                        selectedApps.insert(app.id)
                    } else {
                        selectedApps.remove(app.id)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            Text(app.name)
                .font(.system(size: 11))
                .foregroundColor(.primary)
            
            if let equivalent = app.macOsEquivalent {
                Text("(\(equivalent))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Install method indicator
            installMethodBadge(for: app.installMethod)
        }
        .padding(.leading, 28)
        .padding(.vertical, 4)
    }
    
    private func installMethodBadge(for method: InstallMethod) -> some View {
        let (text, color): (String, Color) = {
            switch method {
            case .homebrew:
                return ("brew", Color.orange)
            case .macAppStore:
                return ("MAS", Color.blue)
            case .directDownload:
                return ("download", Color.purple)
            case .custom:
                return ("custom", Color.gray)
            }
        }()
        
        return Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
    
    private func selectedCountForCategory(_ category: ApplicationCategory) -> Int {
        let apps = ApplicationCatalog.applications(for: category)
        return apps.filter { selectedApps.contains($0.id) }.count
    }
    
    // MARK: - Mac Standardization Section
    
    private var macStandardizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $macStandardizationEnabled) {
                Text("Mac Standardization (Dock, Theme, Power Settings, Wallpaper)")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            
            // Always show option fields
            HStack(spacing: 16) {
                // Computer Name Input
                VStack(alignment: .leading, spacing: 2) {
                    Text("Computer Name (for wallpaper):")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    TextField("Computer Name", text: $computerName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .font(.system(size: 11))
                }
                
                // Custom Icon Path
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Logo (optional):")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        TextField("Select an image...", text: $customIconPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .font(.system(size: 11))
                        
                        Button("Browse") {
                            browseForIcon()
                        }
                        .font(.system(size: 10))
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func browseForIcon() {
        let panel = NSOpenPanel()
        panel.title = "Select Icon Image"
        panel.allowedContentTypes = [.png, .jpeg, .webP, .bmp, .gif, .icns]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            customIconPath = panel.url?.path ?? ""
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            // Status Label
            statusLabel
            
            Spacer()
            
            // Deploy Button
            deployButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private var statusLabel: some View {
        let (text, color) = statusInfo
        return Text(text)
            .font(.system(size: 11))
            .foregroundColor(color)
    }
    
    private var statusInfo: (String, Color) {
        if !networkMonitor.isConnected {
            return ("Network connection required", .red)
        } else if selectedApps.isEmpty && !macStandardizationEnabled {
            return ("Select applications to deploy", .secondary)
        } else {
            return ("Ready to deploy", .secondary)
        }
    }
    
    private var canDeploy: Bool {
        networkMonitor.isConnected && (!selectedApps.isEmpty || macStandardizationEnabled)
    }
    
    private var deployButton: some View {
        Button(action: startDeployment) {
            Text("Deploy")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 140, height: 36)
                .background(canDeploy ? primaryBlue : Color.gray)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!canDeploy)
    }
    
    private func startDeployment() {
        let appsToInstall = ApplicationCatalog.allApplications.filter { selectedApps.contains($0.id) }
        
        deploymentManager.startDeployment(
            applications: appsToInstall,
            macStandardization: macStandardizationEnabled,
            computerName: computerName,
            customIconPath: customIconPath.isEmpty ? nil : customIconPath
        )
    }
    
    // MARK: - Deployment View
    
    private var deploymentView: some View {
        VStack(spacing: 0) {
            // Summary Panel
            deploymentSummaryPanel
                .frame(height: 320)
            
            // Progress Bar - only show while actively deploying (not after completion)
            if deploymentManager.isDeploying && !deploymentManager.isComplete {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            
            // Log View
            deploymentLogView
        }
    }
    
    private var deploymentSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with friendly message
            Text(deploymentManager.friendlyMessage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(primaryBlue)
                .padding(.bottom, 5)
            
            // Task List
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(deploymentManager.tasks) { task in
                        taskRow(for: task)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func taskRow(for task: DeploymentTask) -> some View {
        HStack(spacing: 10) {
            Text(task.statusIcon)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(task.statusDetail)
                    .font(.system(size: 10))
                    .foregroundColor(task.statusColor)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var deploymentLogView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Deployment Log:")
                    .font(.system(size: 11, weight: .bold))
                
                Spacer()
                
                Text(deploymentManager.currentStatus)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(deploymentManager.logEntries) { entry in
                            Text(entry.message)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(entry.color)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: deploymentManager.logEntries.count) { newCount in
                    if let lastEntry = deploymentManager.logEntries.last {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
            .padding(10)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .frame(height: 180)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DeploymentManager())
            .environmentObject(NetworkMonitor())
    }
}
