//
//  NetworkMonitor.swift
//  MacDeploymentToolkit
//
//  Real-time network connectivity monitoring service
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status in real-time
@MainActor
class NetworkMonitor: ObservableObject {
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case ethernet
        case cellular
        case unknown
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Start monitoring network connectivity
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else {
                    self.connectionType = .unknown
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network connectivity
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Perform a connectivity check by pinging a reliable host
    func performConnectivityCheck() async -> Bool {
        // Simple reachability check using a URL request
        guard let url = URL(string: "https://www.google.com") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}
