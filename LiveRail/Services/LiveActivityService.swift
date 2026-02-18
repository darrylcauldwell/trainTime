//
//  LiveActivityService.swift
//  LiveRail
//
//  Manages Live Activity lifecycle for train tracking
//

import Foundation
import ActivityKit

@Observable
final class LiveActivityService {
    private(set) var isTracking = false
    private var activity: Activity<TrainActivityAttributes>?
    private var updateTask: Task<Void, Never>?

    private var apiService: HuxleyAPIService?
    private var serviceID: String?
    private var stationSearch: StationSearchService?

    func startTracking(
        service: TrainService,
        detail: ServiceDetail,
        apiService: HuxleyAPIService,
        stationSearch: StationSearchService
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let serviceID = service.serviceID else { return }

        self.apiService = apiService
        self.serviceID = serviceID
        self.stationSearch = stationSearch

        let attributes = TrainActivityAttributes(
            originName: service.originName,
            originCRS: service.origin?.first?.crs ?? "",
            destinationName: service.destinationName,
            destinationCRS: service.destination?.first?.crs ?? "",
            operatorName: service.operatorName ?? "",
            serviceID: serviceID
        )

        let position = TrainPositionCalculator.calculatePosition(
            callingPoints: detail.allCallingPoints,
            stations: stationSearch.allStations
        )

        let state = TrainActivityAttributes.ContentState(
            currentStation: position?.currentStationName,
            nextStop: position?.nextStationName,
            eta: service.etd,
            delayMinutes: TrainTimeFormatter.delayMinutes(scheduled: service.std, actual: service.etd) ?? 0,
            progress: position?.progress ?? 0,
            platform: service.platform,
            isArrived: false
        )

        do {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
            activity = try Activity<TrainActivityAttributes>.request(
                attributes: attributes,
                content: content
            )
            isTracking = true
            startPeriodicUpdates()
        } catch {
            // Live Activity not available
        }
    }

    func stopTracking() {
        updateTask?.cancel()
        updateTask = nil

        Task {
            guard let activity else { return }
            let finalState = TrainActivityAttributes.ContentState(
                currentStation: nil,
                nextStop: nil,
                eta: nil,
                delayMinutes: 0,
                progress: 1.0,
                platform: nil,
                isArrived: true
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .after(.now + 300))
        }
        self.activity = nil
        isTracking = false
    }

    private func startPeriodicUpdates() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.updateActivity()
            }
        }
    }

    @MainActor
    private func updateActivity() async {
        guard let activity,
              let apiService,
              let serviceID,
              let stationSearch else { return }

        do {
            let detail = try await apiService.fetchServiceDetail(serviceID: serviceID)
            let position = TrainPositionCalculator.calculatePosition(
                callingPoints: detail.allCallingPoints,
                stations: stationSearch.allStations
            )

            // Check if arrived at destination
            let allPoints = detail.allCallingPoints
            let isArrived = allPoints.last?.hasDeparted == true

            let state = TrainActivityAttributes.ContentState(
                currentStation: position?.currentStationName,
                nextStop: position?.nextStationName,
                eta: detail.etd,
                delayMinutes: TrainTimeFormatter.delayMinutes(scheduled: detail.std, actual: detail.etd) ?? 0,
                progress: position?.progress ?? 0,
                platform: detail.platform,
                isArrived: isArrived
            )

            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
            await activity.update(content)

            // Auto-end when arrived
            if isArrived {
                let finalContent = ActivityContent(state: state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(.now + 300))
                self.isTracking = false
                self.activity = nil
                self.updateTask?.cancel()
            }
        } catch {
            // Keep existing state on error
        }
    }
}
