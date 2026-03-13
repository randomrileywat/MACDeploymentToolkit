//
//  PackageInfo.swift
//  MacDeploymentToolkit
//
//  Data-driven package model matching the Supabase `packages` table schema.
//  Replaces hardcoded ApplicationDefinition for dynamic package management.
//

import Foundation
import SwiftUI

// MARK: - PackageInfo

/// A single deployable package fetched from Supabase (or local cache / hardcoded fallback).
/// JSON keys use snake_case matching the Supabase column names.
struct PackageInfo: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let version: String?
    let category: String
    let platforms: [String]
    
    let installMethod: String       // "brew", "dmg", "pkg", "direct_download", "extract_to_desktop"
    let wingetId: String?           // PC only
    let brewId: String?             // Homebrew cask/formula name (Mac)
    let brewType: String?           // "cask" or "formula" (Mac)
    let downloadUrl: String?
    let installArgs: String?
    
    let detectionMethod: String     // "app_bundle", "brew", "file_path", "file_paths", "none"
    let detectionValue: String?
    
    let postInstallCloseWindows: [String]?
    let postInstallCloseDelayMs: Int?
    let pinToTaskbar: Bool?
    let alsoInstallWingetId: String?
    let launchDriverWatcher: Bool?
    
    let fallbackDownloadUrl: String?
    let fallbackInstallArgs: String?
    
    let enabled: Bool?
    let sortOrder: Int?
    
    // MARK: - Coding Keys (snake_case JSON ↔ camelCase Swift)
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case category
        case platforms
        case installMethod = "install_method"
        case wingetId = "winget_id"
        case brewId = "brew_id"
        case brewType = "brew_type"
        case downloadUrl = "download_url"
        case installArgs = "install_args"
        case detectionMethod = "detection_method"
        case detectionValue = "detection_value"
        case postInstallCloseWindows = "post_install_close_windows"
        case postInstallCloseDelayMs = "post_install_close_delay_ms"
        case pinToTaskbar = "pin_to_taskbar"
        case alsoInstallWingetId = "also_install_winget_id"
        case launchDriverWatcher = "launch_driver_watcher"
        case fallbackDownloadUrl = "fallback_download_url"
        case fallbackInstallArgs = "fallback_install_args"
        case enabled
        case sortOrder = "sort_order"
    }
    
    // MARK: - Computed Properties
    
    /// Display name: "Name Version" or just "Name" when version is nil
    var displayName: String {
        if let v = version, !v.isEmpty {
            return "\(name) \(v)"
        }
        return name
    }
    
    /// Resolved category enum (falls back to "System" for unknown values)
    var categoryEnum: ApplicationCategory {
        ApplicationCategory(rawValue: category) ?? .system
    }
    
    /// The platform string for the current architecture
    static var currentPlatform: String {
        SystemArchitecture.isAppleSilicon ? "mac_apple_silicon" : "mac_intel"
    }
    
    /// Returns the effective download URL, preferring architecture-specific fallback if needed
    var effectiveDownloadUrl: String? {
        downloadUrl
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PackageInfo, rhs: PackageInfo) -> Bool {
        lhs.id == rhs.id
    }
}
