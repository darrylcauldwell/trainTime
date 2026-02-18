//
//  TrainPositionCalculator.swift
//  LiveRail
//
//  Interpolate train position from calling points and station coordinates
//

import Foundation
import CoreLocation

struct TrainPosition {
    let coordinate: CLLocationCoordinate2D
    let heading: Double
    let currentStationName: String?
    let nextStationName: String?
    let progress: Double // 0-1 within current segment
}

enum TrainPositionCalculator {

    /// Calculate interpolated train position from calling points and station data
    static func calculatePosition(
        callingPoints: [CallingPoint],
        stations: [Station]
    ) -> TrainPosition? {
        guard callingPoints.count >= 2 else { return nil }

        let now = Date()

        // Find the last station with an actual departure time (train has passed it)
        var lastPassedIndex: Int?
        for (index, point) in callingPoints.enumerated() {
            if point.hasDeparted {
                lastPassedIndex = index
            }
        }

        // If no station passed yet, train is at or before the first station
        guard let passedIndex = lastPassedIndex else {
            if let firstStation = stationForPoint(callingPoints[0], in: stations) {
                return TrainPosition(
                    coordinate: firstStation.coordinate,
                    heading: 0,
                    currentStationName: callingPoints[0].locationName,
                    nextStationName: callingPoints.count > 1 ? callingPoints[1].locationName : nil,
                    progress: 0
                )
            }
            return nil
        }

        // If all stations passed, train is at the last station
        if passedIndex >= callingPoints.count - 1 {
            if let lastStation = stationForPoint(callingPoints[callingPoints.count - 1], in: stations) {
                return TrainPosition(
                    coordinate: lastStation.coordinate,
                    heading: 0,
                    currentStationName: callingPoints[callingPoints.count - 1].locationName,
                    nextStationName: nil,
                    progress: 1
                )
            }
            return nil
        }

        // Train is between passedIndex and passedIndex + 1
        let fromPoint = callingPoints[passedIndex]
        let toPoint = callingPoints[passedIndex + 1]

        guard let fromStation = stationForPoint(fromPoint, in: stations),
              let toStation = stationForPoint(toPoint, in: stations) else {
            return nil
        }

        // Calculate progress through segment
        let departureTime = TrainTimeFormatter.bestTime(
            scheduled: fromPoint.st, estimated: fromPoint.et, actual: fromPoint.at
        )
        let arrivalTime = TrainTimeFormatter.bestTime(
            scheduled: toPoint.st, estimated: toPoint.et, actual: toPoint.at
        )

        guard let depDate = TrainTimeFormatter.dateFromTimeString(departureTime),
              let arrDate = TrainTimeFormatter.dateFromTimeString(arrivalTime, after: depDate) else {
            // Can't calculate time, use midpoint
            let midLat = (fromStation.lat + toStation.lat) / 2
            let midLon = (fromStation.lon + toStation.lon) / 2
            return TrainPosition(
                coordinate: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                heading: bearing(from: fromStation.coordinate, to: toStation.coordinate),
                currentStationName: fromPoint.locationName,
                nextStationName: toPoint.locationName,
                progress: 0.5
            )
        }

        let totalDuration = arrDate.timeIntervalSince(depDate)
        let elapsed = now.timeIntervalSince(depDate)
        let progress = totalDuration > 0 ? max(0, min(1, elapsed / totalDuration)) : 0.5

        // Linear interpolation
        let lat = fromStation.lat + (toStation.lat - fromStation.lat) * progress
        let lon = fromStation.lon + (toStation.lon - fromStation.lon) * progress

        return TrainPosition(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            heading: bearing(from: fromStation.coordinate, to: toStation.coordinate),
            currentStationName: fromPoint.locationName,
            nextStationName: toPoint.locationName,
            progress: progress
        )
    }

    private static func stationForPoint(_ point: CallingPoint, in stations: [Station]) -> Station? {
        guard let crs = point.crs else { return nil }
        return stations.first { $0.crs.uppercased() == crs.uppercased() }
    }

    /// Calculate bearing between two coordinates in degrees
    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
