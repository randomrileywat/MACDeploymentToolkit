//
//  DirectDownloadInstaller.swift
//  MacDeploymentToolkit
//
//  Handles direct download installations (DMG, PKG, ZIP)
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
        
        // Prefer a top-level .pkg, then a top-level .app, then the same pair one folder down.
        // Interactive Studio ships the .app inside a subfolder rather than at the volume root.
        let items = try dmgItems(in: mountPoint, includeChildren: true)
        guard let choice = DMGInstallerLocator.locate(items) else {
            throw DirectDownloadError.appNotFoundInDMG(appName)
        }
        let payload = choice.pathComponents.reduce(mountPoint) { partial, component in
            partial.appendingPathComponent(component)
        }
        switch choice.kind {
        case .pkg:
            try await installFromPKG(payload)
        case .app:
            try installCopiedApp(payload)
        }
    }

    /// One level of children is enough: vendor DMGs nest the payload in a single folder.
    private func dmgItems(in directory: URL, includeChildren: Bool) throws -> [DMGItem] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var items: [DMGItem] = []
        items.reserveCapacity(urls.count)
        for url in urls {
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            let name = url.lastPathComponent
            let shouldDescend = includeChildren
                && isDir.boolValue
                && !name.hasPrefix(".")
                && name != "__MACOSX"
                && url.pathExtension.lowercased() != "app"
            let children = shouldDescend ? try dmgItems(in: url, includeChildren: false) : []
            items.append(DMGItem(name: name, isDirectory: isDir.boolValue, children: children))
        }
        return items
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
        guard let appBundle = extractedContents.first(where: { $0.pathExtension.lowercased() == "app" }) else {
            throw DirectDownloadError.extractFailed(zipPath.lastPathComponent, "No .app bundle found in ZIP")
        }
        try installCopiedApp(appBundle)
    }

    private func installCopiedApp(_ appBundle: URL) throws {
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

// MARK: - DMG payload lookup

struct DMGItem {
    var name: String
    var isDirectory: Bool
    var children: [DMGItem]
}

/// Picks the installer inside a mounted disk image.
/// A `.pkg` wins over a `.app` at the same level. The payload may sit one folder down
/// (CueServer Studio / Interactive Studio keeps the `.app` in a subfolder).
enum DMGInstallerLocator {
    enum Kind: Equatable {
        case pkg
        case app
    }

    struct Choice {
        var kind: Kind
        var pathComponents: [String]
    }

    static func locate(_ items: [DMGItem]) -> Choice? {
        let visible = visibleItems(items)
        if let pkg = visible.first(where: { isPackage($0.name) }) {
            return Choice(kind: .pkg, pathComponents: [pkg.name])
        }
        if let app = visible.first(where: { isApp($0.name) }) {
            return Choice(kind: .app, pathComponents: [app.name])
        }
        for directory in visible where directory.isDirectory && !isApp(directory.name) {
            let children = visibleItems(directory.children)
            if let pkg = children.first(where: { isPackage($0.name) }) {
                return Choice(kind: .pkg, pathComponents: [directory.name, pkg.name])
            }
            if let app = children.first(where: { isApp($0.name) }) {
                return Choice(kind: .app, pathComponents: [directory.name, app.name])
            }
        }
        return nil
    }

    private static func visibleItems(_ items: [DMGItem]) -> [DMGItem] {
        items.filter { !$0.name.hasPrefix(".") && $0.name != "__MACOSX" }
    }

    private static func isPackage(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext == "pkg" || ext == "mpkg"
    }

    private static func isApp(_ name: String) -> Bool {
        (name as NSString).pathExtension.lowercased() == "app"
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
