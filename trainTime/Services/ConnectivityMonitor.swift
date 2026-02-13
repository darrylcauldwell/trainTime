//
//  ConnectivityMonitor.swift
//  trainTime
//
//  NWPathMonitor wrapper for connectivity state
//

import Foundation
import Network

@Observable
final class ConnectivityMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectivity")

    private(set) var isConnected = true
    private(set) var connectionType: ConnectionType = .unknown

    /// Called when connectivity is restored after being offline
    var onReconnect: (() -> Void)?

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }

                // Trigger reconnect callback
                if !wasConnected && path.status == .satisfied {
                    self?.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
