//
//  RefreshCoordinator.swift
//  LiveRail
//
//  Auto-refresh timer + reconnect trigger
//

import Foundation

@Observable
final class RefreshCoordinator {
    private var timer: Timer?
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    var refreshInterval: TimeInterval {
        get { UserDefaults.standard.double(forKey: "refreshInterval").clamped(to: 15...300, default: 30) }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval") }
    }

    /// The action to perform on each refresh tick
    var onRefresh: (() async -> Void)?

    deinit {
        timer?.invalidate()
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.triggerRefresh()
            }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func triggerRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await onRefresh?()
        lastRefresh = Date()
        isRefreshing = false
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
