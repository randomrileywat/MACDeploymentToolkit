//
//  CatalogStore.swift
//  MacDeploymentToolkit
//
//  Remote software catalog, with the built-in list as an offline fallback.
//

import Foundation
import Combine
import SwiftUI

/// Loads the Supabase catalog once at launch. On any failure the built-in
/// `ApplicationCatalog` is shown instead of mixing stale and live rows.
@MainActor
final class CatalogStore: ObservableObject {
    enum Source: Equatable {
        case loading
        case remote(count: Int)
        case bundled(message: String)
    }

    @Published private(set) var applications: [ApplicationCategory: [ApplicationDefinition]] = [:]
    @Published private(set) var source: Source = .loading

    private var didStart = false

    var isReady: Bool {
        if case .loading = source { return false }
        return true
    }

    var statusText: String {
        switch source {
        case .loading:
            return "Loading catalog from Supabase…"
        case .remote(let count):
            return "Catalog loaded from Supabase (\(count) apps)"
        case .bundled:
            return "Using built-in catalog — Supabase was unreachable"
        }
    }

    var sourceDescription: String {
        switch source {
        case .loading:
            return "Software catalog: still loading"
        case .remote:
            return "Software catalog: Supabase packages"
        case .bundled(let message):
            return "Software catalog: built-in fallback (\(message))"
        }
    }

    func applications(for category: ApplicationCategory) -> [ApplicationDefinition] {
        applications[category] ?? []
    }

    var allApplications: [ApplicationDefinition] {
        ApplicationCategory.allCases.flatMap { applications[$0] ?? [] }
    }

    func load() async {
        guard !didStart else { return }
        didStart = true
        do {
            let apps = try await PackageCatalogClient.fetchEnabledMacPackages()
            guard !apps.isEmpty else { throw PackageCatalogError.emptyCatalog }
            applications = Dictionary(grouping: apps, by: \.category)
            source = .remote(count: apps.count)
        } catch {
            applications = ApplicationCatalog.applications
            source = .bundled(message: error.localizedDescription)
        }
    }
}
