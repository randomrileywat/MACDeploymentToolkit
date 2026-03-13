//
//  ContentView.swift
//  MacDeploymentToolkit
//
//  Main application view with application selection tree and deployment controls
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var deploymentManager: DeploymentManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var packageIndex: PackageIndexService
    
    @State private var selectedPackageIds: Set<String> = []
    @State private var expandedCategories: Set<ApplicationCategory> = Set(ApplicationCategory.allCases)
    @State private var macStandardizationEnabled = false
    @State private var computerName: String = ContentView.cleanComputerName()
    @State private var customIconPath: String = ""
    @State private var copiedToClipboard: Bool = false
    
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
        .frame(minWidth: 700, idealWidth: 700, maxWidth: 700,
               minHeight: 680, idealHeight: 680, maxHeight: 680)
        .fixedSize()
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await packageIndex.loadPackages()
            }
        }
    }
    
    // MARK: - Computer Name Helper
    
    /// Strips "'s Mac Mini", "'s MacBook Pro", "'s iMac", etc. from the system computer name
    static func cleanComputerName() -> String {
        let rawName = Host.current().localizedName ?? "Mac"
        
        // Normalize curly/smart apostrophes (U+2019 ') to straight apostrophes (')
        // macOS uses smart quotes in computer names like "ENG-105\u{2019}s Mac Studio"
        let normalized = rawName.replacingOccurrences(of: "\u{2019}", with: "'")
                                .replacingOccurrences(of: "\u{2018}", with: "'")
        
        // Pattern: remove "'s <Mac variant>" suffix
        // Handles: "'s Mac Mini", "'s MacBook Pro", "'s MacBook Air", "'s iMac", "'s Mac Pro", "'s Mac Studio", "'s Mac", etc.
        let suffixes = [
            "'s Mac Mini", "'s Mac mini",
            "'s MacBook Pro", "'s MacBook Air", "'s MacBook",
            "'s iMac Pro", "'s iMac",
            "'s Mac Pro", "'s Mac Studio",
            "'s Mac"  // Catch-all for any other Mac variant
        ]
        
        var cleaned = normalized
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix, options: .caseInsensitive) {
                cleaned = String(cleaned[cleaned.startIndex..<range.lowerBound])
                break
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diversified Mac Deployment Toolkit")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(primaryBlue)
                
                if !deploymentManager.isDeploying {
                    Text("Select applications to install:")
                        .font(.system(size: 11))
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
                    .font(.system(size: 11))
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
                // Data source indicator
                if !packageIndex.dataSource.rawValue.isEmpty {
                    HStack {
                        Text("Source: \(packageIndex.dataSource.rawValue)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(packageIndex.packages.count) packages")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
                
                if packageIndex.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading packages...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ForEach(ApplicationCategory.allCases) { category in
                        let pkgs = packageIndex.packagesByCategory[category.rawValue] ?? []
                        if !pkgs.isEmpty {
                            categorySection(for: category, packages: pkgs)
                        }
                    }
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
    
    private func categorySection(for category: ApplicationCategory, packages: [PackageInfo]) -> some View {
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Text(category.icon)
                        .font(.system(size: 13))
                    
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Selection count for category
                    let count = packages.filter { selectedPackageIds.contains($0.id) }.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium))
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
                ForEach(packages) { pkg in
                    packageRow(for: pkg)
                }
            }
        }
    }
    
    private func packageRow(for pkg: PackageInfo) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { selectedPackageIds.contains(pkg.id) },
                set: { isSelected in
                    if isSelected {
                        selectedPackageIds.insert(pkg.id)
                    } else {
                        selectedPackageIds.remove(pkg.id)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            Text(pkg.displayName)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            if let version = pkg.version, !version.isEmpty {
                Text("v\(version)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Install method indicator
            installMethodBadge(for: pkg.installMethod)
        }
        .padding(.leading, 28)
        .padding(.vertical, 4)
    }
    
    private func installMethodBadge(for method: String) -> some View {
        let (text, color): (String, Color) = {
            switch method {
            case "brew":
                return ("brew", Color.orange)
            case "dmg":
                return ("dmg", Color.purple)
            case "pkg":
                return ("pkg", Color.purple)
            case "zip", "run":
                return (method, Color.purple)
            case "extract_to_desktop":
                return ("extract", Color.gray)
            case "direct_download":
                return ("download", Color.purple)
            default:
                return (method, Color.gray)
            }
        }()
        
        return Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
    
    // MARK: - Mac Standardization Section
    
    private var macStandardizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $macStandardizationEnabled) {
                Text("Mac Standardization (Dock, Theme, Power Settings, Wallpaper)")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            
            // Always show option fields
            HStack(spacing: 16) {
                // Computer Name Input
                VStack(alignment: .leading, spacing: 2) {
                    Text("Computer Name (for wallpaper):")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    TextField("Computer Name", text: $computerName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .font(.system(size: 12))
                }
                
                // Custom Icon Path
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Logo (optional):")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        TextField("Select an image...", text: $customIconPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .font(.system(size: 12))
                        
                        Button("Browse") {
                            browseForIcon()
                        }
                        .font(.system(size: 11))
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
            .font(.system(size: 12))
            .foregroundColor(color)
    }
    
    private var statusInfo: (String, Color) {
        if !networkMonitor.isConnected {
            return ("Network connection required", .red)
        } else if selectedPackageIds.isEmpty && !macStandardizationEnabled {
            return ("Select applications to deploy", .secondary)
        } else {
            return ("Ready to deploy", .secondary)
        }
    }
    
    private var canDeploy: Bool {
        networkMonitor.isConnected && (!selectedPackageIds.isEmpty || macStandardizationEnabled)
    }
    
    private var deployButton: some View {
        Button(action: startDeployment) {
            Text("Deploy")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 150, height: 38)
                .background(canDeploy ? primaryBlue : Color.gray)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!canDeploy)
    }
    
    private func startDeployment() {
        let pkgsToInstall = packageIndex.packages.filter { selectedPackageIds.contains($0.id) }
        
        deploymentManager.startDeployment(
            packages: pkgsToInstall,
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
                .frame(maxHeight: .infinity)
            
            // Progress Bar - only show while actively deploying (not after completion)
            if deploymentManager.isDeploying && !deploymentManager.isComplete {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 16)
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
                .font(.system(size: 15, weight: .bold))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func taskRow(for task: DeploymentTask) -> some View {
        HStack(spacing: 10) {
            Text(task.statusIcon)
                .font(.system(size: 15))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(task.statusDetail)
                    .font(.system(size: 11))
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
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                // Copy Log button
                Button(action: {
                    let logText = deploymentManager.logEntries.map { entry in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm:ss"
                        return "[\(formatter.string(from: entry.timestamp))] \(entry.message)"
                    }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                    copiedToClipboard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedToClipboard = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(copiedToClipboard ? "Copied!" : "Copy Log")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(copiedToClipboard ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(deploymentManager.logEntries.isEmpty)
                
                Text(deploymentManager.currentStatus)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(deploymentManager.logEntries) { entry in
                            Text(entry.message)
                                .font(.system(size: 11, design: .monospaced))
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
            .environmentObject(PackageIndexService())
    }
}
