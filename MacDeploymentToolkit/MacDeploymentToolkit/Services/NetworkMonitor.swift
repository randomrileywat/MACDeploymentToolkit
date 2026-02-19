//
//  NetworkMonitor.swift
//  MacDeploymentToolkit
//
//  Real-time network connectivity monitoring service
//

import Foundation
import SwiftUI
import SystemConfiguration

/// Monitors network connectivity status in real-time
@MainActor
class NetworkMonitor: ObservableObject {
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    
    private var timer: Timer?
    
    enum ConnectionType {
        case wifi
        case ethernet
        case cellular
        case unknown
    }
    
    init() {
        // Check immediately
        isConnected = performConnectivityCheckSync()
        // Then check every 5 seconds
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// Start periodic network monitoring
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            // Perform check synchronously since SCNetworkReachability is synchronous
            // Note: performConnectivityCheckSync() is safe to call off-main because it
            // only uses SCNetworkReachability (no actor-isolated state).
            let connected = self?.performConnectivityCheckSync() ?? false
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                self.isConnected = connected
            }
        }
    }
    
    /// Check network connection using SCNetworkReachability
    private func checkConnection() async {
        isConnected = performConnectivityCheckSync()
    }
    
    /// Perform a connectivity check using SystemConfiguration (synchronous)
    func performConnectivityCheckSync() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(reachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
}
