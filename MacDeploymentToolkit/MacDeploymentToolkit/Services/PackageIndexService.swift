//
//  PackageIndexService.swift
//  MacDeploymentToolkit
//
//  3-tier fallback package index:
//    1. Supabase REST API → cache locally & use
//    2. Local JSON cache  → filter by platform & use
//    3. Hardcoded defaults → always available, compiled into the app
//

import Foundation

/// Fetches the list of deployable packages using a 3-tier fallback strategy.
@MainActor
class PackageIndexService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var packages: [PackageInfo] = []
    @Published var packagesByCategory: [String: [PackageInfo]] = [:]
    @Published var isLoading = false
    @Published var dataSource: DataSource = .none
    
    enum DataSource: String {
        case supabase = "Supabase (live)"
        case cache = "Local cache"
        case hardcoded = "Built-in defaults"
        case none = ""
    }
    
    // MARK: - Configuration
    
    private let supabaseUrl = "https://incdoepqrbwaagatikgb.supabase.co"
    private let supabaseServiceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluY2RvZXBxcmJ3YWFnYXRpa2diIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkwNzA0OSwiZXhwIjoyMDc4NDgzMDQ5fQ.5qjYJq7OGWAdBIVZqzpRE71aJEEOvbko9m3VDVJuQQA"
    
    private var cacheFileUrl: URL {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacDeploymentToolkit")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("package_cache.json")
    }
    
    // MARK: - Public API
    
    /// Load packages using the 3-tier fallback. Call once at app launch or on refresh.
    func loadPackages() async {
        isLoading = true
        defer { isLoading = false }
        
        let platform = PackageInfo.currentPlatform
        
        // Tier 1: Supabase REST API
        if let remote = await fetchFromSupabase(platform: platform) {
            packages = remote
            packagesByCategory = groupByCategory(remote)
            dataSource = .supabase
            cachePackages(remote)
            return
        }
        
        // Tier 2: Local JSON cache
        if let cached = loadCachedPackages(platform: platform) {
            packages = cached
            packagesByCategory = groupByCategory(cached)
            dataSource = .cache
            return
        }
        
        // Tier 3: Hardcoded defaults
        let hardcoded = ApplicationCatalog.hardcodedPackages(for: platform)
        packages = hardcoded
        packagesByCategory = groupByCategory(hardcoded)
        dataSource = .hardcoded
    }
    
    // MARK: - Tier 1: Supabase
    
    private func fetchFromSupabase(platform: String) async -> [PackageInfo]? {
        // Build URL: GET /rest/v1/packages?enabled=eq.true&platforms=cs.{platform}&order=sort_order.asc&select=*
        var components = URLComponents(string: "\(supabaseUrl)/rest/v1/packages")
        components?.queryItems = [
            URLQueryItem(name: "enabled", value: "eq.true"),
            URLQueryItem(name: "platforms", value: "cs.{\(platform)}"),
            URLQueryItem(name: "order", value: "sort_order.asc"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(supabaseServiceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseServiceKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await urlSessionData(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let packages = try decoder.decode([PackageInfo].self, from: data)
            return packages.isEmpty ? nil : packages
        } catch {
            print("PackageIndexService: Supabase fetch failed — \(error.localizedDescription)")
            return nil
        }
    }
    
    /// macOS 11 compatible URLSession async wrapper
    private func urlSessionData(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
    
    // MARK: - Tier 2: Local Cache
    
    private func cachePackages(_ packages: [PackageInfo]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(packages)
            try data.write(to: cacheFileUrl, options: .atomic)
        } catch {
            print("PackageIndexService: Failed to cache packages — \(error.localizedDescription)")
        }
    }
    
    private func loadCachedPackages(platform: String) -> [PackageInfo]? {
        guard FileManager.default.fileExists(atPath: cacheFileUrl.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheFileUrl)
            let decoder = JSONDecoder()
            let allPackages = try decoder.decode([PackageInfo].self, from: data)
            
            // Filter cached packages by current platform
            let filtered = allPackages.filter { $0.platforms.contains(platform) }
            return filtered.isEmpty ? nil : filtered
        } catch {
            print("PackageIndexService: Failed to load cache — \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func groupByCategory(_ packages: [PackageInfo]) -> [String: [PackageInfo]] {
        Dictionary(grouping: packages, by: { $0.category })
    }
}
