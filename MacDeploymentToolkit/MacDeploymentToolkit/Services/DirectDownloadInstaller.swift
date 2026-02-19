//
//  DirectDownloadInstaller.swift
//  MacDeploymentToolkit
//
//  Handles direct download installations (DMG, PKG, ZIP)
//

import Foundation

/// Handles application installation via direct downloads
class DirectDownloadInstaller {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    
    /// Admin password set by DeploymentManager after initial prompt; used for sudo -S
    var adminPassword: String?
    
    init() {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("MacDeploymentToolkit")
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Install an application from a direct download URL
    func install(name: String, url: String, format: InstallMethod.InstallerFormat) async throws {
        guard let downloadUrl = URL(string: url) else {
            throw DirectDownloadError.invalidUrl(url)
        }
        
        // Download the installer
        let localFile = try await downloadFile(from: downloadUrl, name: name, format: format)
        
        defer {
            // Cleanup downloaded file
            try? fileManager.removeItem(at: localFile)
        }
        
        // Install based on format
        switch format {
        case .dmg:
            try await installFromDMG(localFile, appName: name)
        case .pkg:
            try await installFromPKG(localFile)
        case .zip:
            try await installFromZIP(localFile, appName: name)
        case .app:
            try await installAppBundle(localFile, appName: name)
        case .run:
            try await installFromRUN(localFile, appName: name)
        }
    }
    
    // MARK: - Download
    
    private func downloadFile(from url: URL, name: String, format: InstallMethod.InstallerFormat) async throws -> URL {
        let fileExtension = format.rawValue
        let localUrl = tempDirectory.appendingPathComponent("\(name).\(fileExtension)")
        
        // Remove existing file if present
        try? fileManager.removeItem(at: localUrl)
        
        // Use continuation-based download for macOS 11 compatibility
        let (tempUrl, response) = try await downloadWithContinuation(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DirectDownloadError.downloadFailed(name)
        }
        
        try fileManager.moveItem(at: tempUrl, to: localUrl)
        return localUrl
    }
    
    /// Downloads a file using URLSession with async/await compatibility for macOS 11+
    private func downloadWithContinuation(from url: URL) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { localUrl, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localUrl = localUrl, let response = response else {
                    continuation.resume(throwing: DirectDownloadError.downloadFailed(url.lastPathComponent))
                    return
                }
                
                // Move to a temp location we control (the original gets deleted after this callback)
                let tempDestination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                
                do {
                    try FileManager.default.moveItem(at: localUrl, to: tempDestination)
                    continuation.resume(returning: (tempDestination, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    // MARK: - DMG Installation
    
    private func installFromDMG(_ dmgPath: URL, appName: String) async throws {
        // Mount the DMG
        let mountPoint = try await mountDMG(dmgPath)
        
        defer {
            // Unmount when done
            Task {
                try? await unmountDMG(mountPoint)
            }
        }
        
        // Look for .pkg or .app in the mounted volume
        let contents = try fileManager.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        
        // Check for .pkg installer FIRST (common for Blackmagic, driver packages, etc.)
        // Many DMGs contain an installer .app alongside a .pkg — the .pkg is the proper
        // installation method, while the .app is just a GUI wrapper or uninstaller.
        if let pkgInstaller = contents.first(where: { $0.pathExtension == "pkg" }) {
            try await installFromPKG(pkgInstaller)
            return
        }
        
        // Fall back to .app bundle (simple drag-and-drop style DMGs)
        if let appBundle = contents.first(where: { $0.pathExtension == "app" }) {
            let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(appBundle.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: appBundle, to: destination)
            return
        }
        
        // Check subdirectories for .pkg files (some DMGs nest them)
        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                if let subContents = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                    if let pkgInstaller = subContents.first(where: { $0.pathExtension == "pkg" }) {
                        try await installFromPKG(pkgInstaller)
                        return
                    }
                }
            }
        }
        
        throw DirectDownloadError.appNotFoundInDMG(appName)
    }
    
    private func mountDMG(_ dmgPath: URL) async throws -> URL {
        // Use -noautoopen to prevent Finder from opening the volume
        // Do NOT use -quiet: we need the output to parse the mount point
        // Use yes | to auto-accept any license agreements (e.g., Blackmagic DMGs)
        let result = try await runShellCommand("yes | hdiutil attach '\(dmgPath.path)' -nobrowse -noautoopen -noverify")
        
        if result.exitCode != 0 {
            throw DirectDownloadError.mountFailed(dmgPath.lastPathComponent, result.error)
        }
        
        // Parse mount point from hdiutil output
        // Output format: `/dev/diskXsY    Apple_HFS    /Volumes/VolumeName`
        // Fields are separated by tabs, but spacing can vary
        let lines = result.output.components(separatedBy: "\n")
        for line in lines.reversed() {
            // Try tab-separated first
            let components = line.components(separatedBy: "\t")
            for component in components.reversed() {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("/Volumes/") {
                    return URL(fileURLWithPath: trimmed)
                }
            }
            // Fallback: scan for /Volumes/ anywhere in the line (handles varied whitespace)
            if let range = line.range(of: "/Volumes/") {
                let mountPath = String(line[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !mountPath.isEmpty {
                    return URL(fileURLWithPath: mountPath)
                }
            }
        }
        
        throw DirectDownloadError.mountFailed(dmgPath.lastPathComponent, "Could not determine mount point")
    }
    
    private func unmountDMG(_ mountPoint: URL) async throws {
        _ = try await runShellCommand("hdiutil detach '\(mountPoint.path)' -quiet")
    }
    
    // MARK: - PKG Installation
    
    private func installFromPKG(_ pkgPath: URL) async throws {
        // PKG installation requires elevated privileges
        // Use osascript with administrator privileges (don't use sudo inside - osascript already elevates)
        let command = "installer -pkg '\(pkgPath.path)' -target /"
        let result = try await runShellCommandWithElevation(command)
        
        if result.exitCode != 0 {
            throw DirectDownloadError.pkgInstallFailed(pkgPath.lastPathComponent, result.error)
        }
    }
    
    // MARK: - ZIP Installation
    
    private func installFromZIP(_ zipPath: URL, appName: String) async throws {
        let extractDir = tempDirectory.appendingPathComponent("extract_\(appName)")
        
        // Create extraction directory
        try? fileManager.removeItem(at: extractDir)
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: extractDir)
        }
        
        // Extract ZIP
        let result = try await runShellCommand("unzip -q '\(zipPath.path)' -d '\(extractDir.path)'")
        
        if result.exitCode != 0 {
            throw DirectDownloadError.extractFailed(zipPath.lastPathComponent, result.error)
        }
        
        // Find and install .app bundle from extracted contents
        let extractedContents = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        guard let appBundle = extractedContents.first(where: { $0.pathExtension == "app" }) else {
            throw DirectDownloadError.extractFailed(zipPath.lastPathComponent, "No .app bundle found in ZIP")
        }
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(appBundle.lastPathComponent)
        
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try fileManager.copyItem(at: appBundle, to: destination)
    }
    
    // MARK: - App Bundle Installation
    
    private func installAppBundle(_ appPath: URL, appName: String) async throws {
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent("\(appName).app")
        
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try fileManager.copyItem(at: appPath, to: destination)
    }
    
    // MARK: - RUN Script Installation (Self-extracting shell script)
    
    private func installFromRUN(_ runPath: URL, appName: String) async throws {
        // Make the .run file executable
        let chmodResult = try await runShellCommand("chmod +x '\(runPath.path)'")
        if chmodResult.exitCode != 0 {
            throw DirectDownloadError.runScriptFailed(appName, "Failed to make script executable: \(chmodResult.error)")
        }
        
        // Execute the .run script with elevated privileges
        // The script is self-extracting and will install the application
        let result = try await runShellCommandWithElevation(runPath.path)
        
        if result.exitCode != 0 {
            throw DirectDownloadError.runScriptFailed(appName, result.error)
        }
    }
    
    // MARK: - Shell Command Execution
    
    private func runShellCommand(_ command: String) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: ShellResult(
                    output: output,
                    error: error,
                    exitCode: process.terminationStatus
                ))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func runShellCommandWithElevation(_ command: String) async throws -> ShellResult {
        // Inject PATH into command so it survives sudo/osascript environment resets
        let fullCommand = "export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH && \(command)"
        
        // Use stored admin password with sudo -S to avoid repeated password prompts
        guard let password = adminPassword else {
            // Fallback: osascript dialog (will prompt each time)
            let escapedCmd = fullCommand.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escapedCmd)\" with administrator privileges"
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        continuation.resume(returning: ShellResult(output: output, error: error, exitCode: process.terminationStatus))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        // Primary path: pipe stored password to sudo -S (no GUI prompt)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-S", "/bin/zsh", "-c", fullCommand]
                process.standardInput = inputPipe
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    
                    let passwordData = (password + "\n").data(using: .utf8)!
                    inputPipe.fileHandleForWriting.write(passwordData)
                    inputPipe.fileHandleForWriting.closeFile()
                    
                    process.waitUntilExit()
                    
                    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: ShellResult(
                        output: output,
                        error: error,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errors

enum DirectDownloadError: LocalizedError {
    case invalidUrl(String)
    case downloadFailed(String)
    case mountFailed(String, String)
    case appNotFoundInDMG(String)
    case pkgInstallFailed(String, String)
    case extractFailed(String, String)
    case runScriptFailed(String, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl(let url):
            return "Invalid download URL: \(url)"
        case .downloadFailed(let name):
            return "Failed to download \(name)"
        case .mountFailed(let name, let error):
            return "Failed to mount \(name): \(error)"
        case .appNotFoundInDMG(let name):
            return "Could not find .app or .pkg in disk image for \(name)"
        case .pkgInstallFailed(let name, let error):
            return "Failed to install \(name): \(error)"
        case .extractFailed(let name, let error):
            return "Failed to extract \(name): \(error)"
        case .runScriptFailed(let name, let error):
            return "Failed to run installer script for \(name): \(error)"
        }
    }
}
