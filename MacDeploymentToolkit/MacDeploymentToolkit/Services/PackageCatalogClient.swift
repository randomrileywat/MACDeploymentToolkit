//
//  PackageCatalogClient.swift
//  MacDeploymentToolkit
//
//  Loads the software catalog from the public Supabase `packages` table.
//  Uses the anon key only. Row Level Security allows this read.
//  Do not embed a privileged Supabase key in this app.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum PackageCatalogError: LocalizedError {
    case invalidURL
    case requestFailed(Int)
    case emptyCatalog
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid catalog URL"
        case .requestFailed(let code):
            return "Catalog request failed (HTTP \(code))"
        case .emptyCatalog:
            return "Catalog response had no installable Mac packages"
        case .decodingFailed:
            return "Catalog response could not be read"
        }
    }
}

/// Fetches enabled Mac rows and maps them onto `ApplicationDefinition`.
enum PackageCatalogClient {

    /// Project URL. Public.
    static let supabaseURL = URL(string: "https://incdoepqrbwaagatikgb.supabase.co")!
    static let packagesURL = URL(string: "https://incdoepqrbwaagatikgb.supabase.co/rest/v1/packages")!

    /// Legacy anon JWT. This is the publishable client key for this project
    /// (no `sb_publishable_` key is configured). It is safe to ship in the app.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5MDcwNDksImV4cCI6MjA3ODQ4MzA0OX0.bqGIGIT-HxpcM-AH3Xd4lyLBN3cwAmNFuxp6V1JmvLw"

    /// Live `platforms` values are `mac_apple_silicon` and `mac_intel`.
    /// `mac` and `mac_arm` are accepted so a later rename still matches.
    static let macPlatformTokens = ["mac_apple_silicon", "mac_intel", "mac_arm", "mac"]

    private static let appleSiliconTokens: Set<String> = ["mac_apple_silicon", "mac_arm", "mac_arm64", "arm64"]
    private static let intelTokens: Set<String> = ["mac_intel", "mac_x86_64", "mac_x86", "intel"]
    private static let genericMacTokens: Set<String> = ["mac", "macos", "osx", "darwin"]

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    /// Enabled Mac rows for this CPU. Chip-specific rows (Angry IP Scanner, PTP Track Hound)
    /// are kept only when `platforms` includes the running architecture.
    static func fetchEnabledMacPackages(
        isAppleSilicon: Bool = SystemArchitecture.isAppleSilicon
    ) async throws -> [ApplicationDefinition] {
        guard var components = URLComponents(url: packagesURL, resolvingAgainstBaseURL: false) else {
            throw PackageCatalogError.invalidURL
        }

        // `select=*` so columns added later (fallback_download_url_arm / _intel,
        // download_url_arm) show up without an app update. decodeIfPresent ignores
        // them until they exist.
        let platformFilter = macPlatformTokens
            .map { "platforms.cs.{\($0)}" }
            .joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "enabled", value: "eq.true"),
            URLQueryItem(name: "or", value: "(\(platformFilter))"),
            URLQueryItem(name: "order", value: "sort_order.asc,name.asc")
        ]
        guard let url = components.url else {
            throw PackageCatalogError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PackageCatalogError.requestFailed(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw PackageCatalogError.requestFailed(http.statusCode)
        }
        return try applications(from: data, isAppleSilicon: isAppleSilicon)
    }

    static func applications(from data: Data, isAppleSilicon: Bool) throws -> [ApplicationDefinition] {
        let decoded: [FailableDecodable<PackageRow>]
        do {
            decoded = try JSONDecoder().decode([FailableDecodable<PackageRow>].self, from: data)
        } catch {
            throw PackageCatalogError.decodingFailed
        }
        let rows = decoded.compactMap(\.value)
        return rows.compactMap { application(from: $0, isAppleSilicon: isAppleSilicon) }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func matchesCurrentMac(_ platforms: [String], isAppleSilicon: Bool) -> Bool {
        let tokens = Set(platforms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let chipTokens = appleSiliconTokens.union(intelTokens)
        if isAppleSilicon {
            if !tokens.isDisjoint(with: appleSiliconTokens) { return true }
        } else if !tokens.isDisjoint(with: intelTokens) {
            return true
        }
        // A bare "mac" row is universal. A row that also names a chip stays on that chip.
        return !tokens.isDisjoint(with: genericMacTokens) && tokens.isDisjoint(with: chipTokens)
    }

    private static func application(from row: PackageRow, isAppleSilicon: Bool) -> ApplicationDefinition? {
        if row.enabled == false { return nil }
        guard matchesCurrentMac(row.platforms, isAppleSilicon: isAppleSilicon) else { return nil }
        guard let installMethod = installMethod(for: row) else { return nil }

        let detection = row.detectionMethod.flatMap { DetectionMethod(rawValue: $0.lowercased()) }
        return ApplicationDefinition(
            id: row.id,
            name: row.name,
            category: category(from: row.category),
            installMethod: installMethod,
            packageId: nonEmpty(row.brewId),
            downloadUrl: nonEmpty(row.downloadUrl),
            downloadUrlArm: nonEmpty(row.downloadUrlArm),
            fallbackDownloadUrl: nonEmpty(row.fallbackDownloadUrl),
            fallbackDownloadUrlArm: nonEmpty(row.fallbackDownloadUrlArm),
            fallbackDownloadUrlIntel: nonEmpty(row.fallbackDownloadUrlIntel),
            version: nonEmpty(row.version),
            detectionMethod: detection,
            detectionValue: nonEmpty(row.detectionValue),
            sortOrder: row.sortOrder ?? 0
        )
    }

    private static func installMethod(for row: PackageRow) -> InstallMethod? {
        let method = row.installMethod.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch method {
        case "brew", "homebrew":
            if nonEmpty(row.brewId) != nil {
                let brewType: InstallMethod.HomebrewType = nonEmpty(row.brewType)?.lowercased() == "formula" ? .formula : .cask
                return .homebrew(type: brewType)
            }
            if let format = format(for: row) {
                return .directDownload(format: format)
            }
            return nil
        case "dmg", "pkg", "zip", "app", "run":
            guard let format = InstallMethod.InstallerFormat(rawValue: method) else { return nil }
            return .directDownload(format: format)
        case "direct_download":
            guard let format = format(for: row) else { return nil }
            return .directDownload(format: format)
        case "extract_to_desktop":
            return .custom(handler: customHandler(for: row.name))
        default:
            if let format = InstallMethod.InstallerFormat(rawValue: method) {
                return .directDownload(format: format)
            }
            return nil
        }
    }

    private static func format(for row: PackageRow) -> InstallMethod.InstallerFormat? {
        if let url = nonEmpty(row.downloadUrl), let format = InstallMethod.InstallerFormat(downloadURL: url) {
            return format
        }
        if let url = nonEmpty(row.fallbackDownloadUrl), let format = InstallMethod.InstallerFormat(downloadURL: url) {
            return format
        }
        return nil
    }

    private static func customHandler(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("audio") { return "audiotestcontent" }
        if lower.contains("video") { return "videotestcontent" }
        return "extracttodesktop"
    }

    private static func category(from raw: String) -> ApplicationCategory {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "audio": return .audio
        case "video": return .video
        case "lighting": return .lighting
        case "networking", "network": return .networking
        case "control": return .control
        case "system": return .system
        case "test content", "testcontent", "test_content": return .testContent
        default:
            return ApplicationCategory.allCases.first { $0.rawValue.lowercased() == normalized } ?? .system
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// `URLSession.data(from:)` is macOS 12+. This project deploys to macOS 11.
    private static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: PackageCatalogError.requestFailed(-1))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}

private struct PackageRow: Decodable {
    let id: UUID
    let name: String
    let version: String?
    let category: String
    let platforms: [String]
    let installMethod: String
    let downloadUrl: String?
    let downloadUrlArm: String?
    let fallbackDownloadUrl: String?
    let fallbackDownloadUrlArm: String?
    let fallbackDownloadUrlIntel: String?
    let enabled: Bool?
    let sortOrder: Int?
    let brewId: String?
    let brewType: String?
    let detectionMethod: String?
    let detectionValue: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, category, platforms, enabled
        case installMethod = "install_method"
        case downloadUrl = "download_url"
        case downloadUrlArm = "download_url_arm"
        case fallbackDownloadUrl = "fallback_download_url"
        case fallbackDownloadUrlArm = "fallback_download_url_arm"
        case fallbackDownloadUrlIntel = "fallback_download_url_intel"
        case sortOrder = "sort_order"
        case brewId = "brew_id"
        case brewType = "brew_type"
        case detectionMethod = "detection_method"
        case detectionValue = "detection_value"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        category = try container.decode(String.self, forKey: .category)
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? []
        installMethod = try container.decode(String.self, forKey: .installMethod)
        downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        downloadUrlArm = try container.decodeIfPresent(String.self, forKey: .downloadUrlArm)
        fallbackDownloadUrl = try container.decodeIfPresent(String.self, forKey: .fallbackDownloadUrl)
        fallbackDownloadUrlArm = try container.decodeIfPresent(String.self, forKey: .fallbackDownloadUrlArm)
        fallbackDownloadUrlIntel = try container.decodeIfPresent(String.self, forKey: .fallbackDownloadUrlIntel)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        brewId = try container.decodeIfPresent(String.self, forKey: .brewId)
        brewType = try container.decodeIfPresent(String.self, forKey: .brewType)
        detectionMethod = try container.decodeIfPresent(String.self, forKey: .detectionMethod)
        detectionValue = try container.decodeIfPresent(String.self, forKey: .detectionValue)
    }
}

/// Decodes an array element even when one row is malformed, so one bad package
/// does not throw away the rest of the catalog.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
