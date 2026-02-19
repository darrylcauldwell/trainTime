//
//  JourneyAPIModels.swift
//  LiveRail
//
//  API response models for TfL and TransportAPI journey planning
//

import Foundation

// MARK: - TfL API Models

struct TfLJourneyResponse: Codable {
    let journeys: [TfLJourney]
}

struct TfLJourney: Codable {
    let startDateTime: String?
    let duration: Int?
    let arrivalDateTime: String?
    let legs: [TfLLeg]
}

struct TfLLeg: Codable {
    let mode: TfLMode?
    // TfL uses both naming conventions depending on endpoint/version
    let departureTime: String?
    let arrivalTime: String?
    let scheduledDepartureTime: String?
    let scheduledArrivalTime: String?
    let duration: Int?
    let instruction: TfLInstruction?
    let disruption: TfLDisruption?
    let path: TfLPath?
    let routeOptions: [TfLRouteOption]?
    // Boarding and alighting point — more reliable than path.stopPoints.first/last
    let departurePoint: TfLPoint?
    let arrivalPoint: TfLPoint?

    var effectiveDepartureTime: String? { departureTime ?? scheduledDepartureTime }
    var effectiveArrivalTime: String? { arrivalTime ?? scheduledArrivalTime }
}

struct TfLPoint: Codable {
    let naptanId: String?   // NaptanId for arrivals lookup (e.g. "940GZZLUOXC")
    let commonName: String?
    let lat: Double?
    let lon: Double?
    let platformName: String?
}

struct TfLMode: Codable {
    let id: String?
    let name: String?
}

struct TfLInstruction: Codable {
    let summary: String?
    let detailed: String?
}

struct TfLDisruption: Codable {
    let description: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case description, category
    }
}

struct TfLPath: Codable {
    let lineString: String?
    let stopPoints: [TfLStopPoint]?
    let elevation: [TfLElevation]?

    enum CodingKeys: String, CodingKey {
        case lineString, stopPoints, elevation
    }
}

struct TfLStopPoint: Codable {
    let id: String?
    let name: String?
    let lat: Double?
    let lon: Double?
    let platformName: String?
    let modes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon
        case platformName, modes
    }
}

struct TfLElevation: Codable {
    let distance: Int?
    let startLat: Double?
    let startLon: Double?
    let endLat: Double?
    let endLon: Double?
    let heightFromPreviousPoint: Int?
    let gradient: Double?

    enum CodingKeys: String, CodingKey {
        case distance, startLat, startLon, endLat, endLon
        case heightFromPreviousPoint, gradient
    }
}

struct TfLRouteOption: Codable {
    let name: String?
    let directions: [String]?
    let lineIdentifier: TfLLineIdentifier?

    enum CodingKeys: String, CodingKey {
        case name, directions, lineIdentifier
    }
}

struct TfLLineIdentifier: Codable {
    let id: String?
    let name: String?
    let modeName: String?
    let operatorId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, modeName, operatorId
    }
}

// MARK: - TfL Arrivals (StopPoint/{id}/Arrivals)

struct TfLArrivalPrediction: Codable {
    let lineId: String?
    let expectedArrival: String?
    let destinationNaptanId: String?  // For direction filtering (northbound vs southbound)
    let platformName: String?         // e.g. "Northbound - Platform 6"
}

// MARK: - TransportAPI Models (for future use)

struct TransportAPIJourneyResponse: Codable {
    let routes: [TransportAPIRoute]

    enum CodingKeys: String, CodingKey {
        case routes
    }
}

struct TransportAPIRoute: Codable {
    let departureTime: String
    let arrivalTime: String
    let duration: String
    let routeParts: [TransportAPIRoutePart]

    enum CodingKeys: String, CodingKey {
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case duration
        case routeParts = "route_parts"
    }
}

struct TransportAPIRoutePart: Codable {
    let mode: String
    let fromStationName: String?
    let toStationName: String?
    let fromStationCode: String?
    let toStationCode: String?
    let departureTime: String?
    let arrivalTime: String?
    let operatorName: String?
    let platform: String?
    let serviceTimetable: TransportAPIServiceTimetable?

    enum CodingKeys: String, CodingKey {
        case mode
        case fromStationName = "from_station_name"
        case toStationName = "to_station_name"
        case fromStationCode = "from_station_code"
        case toStationCode = "to_station_code"
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case operatorName = "operator_name"
        case platform
        case serviceTimetable = "service_timetable"
    }
}

struct TransportAPIServiceTimetable: Codable {
    let id: String?

    enum CodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - Mapping Functions

extension TfLJourneyResponse {
    /// Map TfL response to Journey models
    func mapToJourneys() -> [Journey] {
        journeys.compactMap { mapTfLJourney($0) }
    }

    private func mapTfLJourney(_ tflJourney: TfLJourney) -> Journey? {
        // Parse dates — fall back to leg times if journey-level times absent
        let mappedLegs = tflJourney.legs.compactMap { mapTfLLeg($0) }
        guard !mappedLegs.isEmpty else { return nil }

        let departureDate = parseISO8601(tflJourney.startDateTime ?? "") ?? mappedLegs.first?.departureTime ?? Date()
        let arrivalDate = parseISO8601(tflJourney.arrivalDateTime ?? "") ?? mappedLegs.last?.arrivalTime ?? Date()
        let durationSeconds = TimeInterval((tflJourney.duration ?? 0) * 60)

        return Journey(
            id: UUID().uuidString,
            legs: mappedLegs,
            departureTime: departureDate,
            arrivalTime: arrivalDate,
            duration: durationSeconds > 0 ? durationSeconds : arrivalDate.timeIntervalSince(departureDate)
        )
    }

    private func mapTfLLeg(_ tflLeg: TfLLeg) -> JourneyLeg? {
        // Require at least a mode and some time data
        guard let modeObj = tflLeg.mode,
              let modeId = modeObj.id else { return nil }

        let mode = mapTfLMode(modeId)

        // Try all time field variants
        let deptStr = tflLeg.effectiveDepartureTime
        let arrStr = tflLeg.effectiveArrivalTime

        // For walking legs without times, use a zero-duration placeholder
        let departureDate = parseISO8601(deptStr ?? "") ?? Date()
        let arrivalDate = parseISO8601(arrStr ?? "") ?? departureDate.addingTimeInterval(TimeInterval((tflLeg.duration ?? 0) * 60))
        let durationSeconds = TimeInterval((tflLeg.duration ?? 0) * 60)

        // Use departurePoint/arrivalPoint for accurate boarding/alighting stations.
        // Fall back to path.stopPoints if unavailable (older API responses).
        let stopPoints = tflLeg.path?.stopPoints ?? []
        let firstStop = stopPoints.first
        let lastStop = stopPoints.last

        let originName = tflLeg.departurePoint?.commonName
            ?? firstStop?.name
            ?? tflLeg.instruction?.summary
            ?? "Departure point"
        let originLat = tflLeg.departurePoint?.lat ?? firstStop?.lat
        let originLon = tflLeg.departurePoint?.lon ?? firstStop?.lon

        let destName = tflLeg.arrivalPoint?.commonName
            ?? lastStop?.name
            ?? "Arrival point"
        let destLat = tflLeg.arrivalPoint?.lat ?? lastStop?.lat
        let destLon = tflLeg.arrivalPoint?.lon ?? lastStop?.lon

        // NaptanId from departurePoint/arrivalPoint — reliable source for arrivals lookup.
        // path.stopPoints contain intermediate stops only (excluding the boarding station itself).
        let originStopId = tflLeg.departurePoint?.naptanId
        let destStopId = tflLeg.arrivalPoint?.naptanId

        let origin = JourneyLocation(
            name: originName,
            crs: extractCRSFromStopId(firstStop?.id),
            latitude: originLat,
            longitude: originLon,
            stopId: originStopId
        )
        let destination = JourneyLocation(
            name: destName,
            crs: extractCRSFromStopId(lastStop?.id),
            latitude: destLat,
            longitude: destLon,
            stopId: destStopId
        )

        let lineIdentifier = tflLeg.routeOptions?.first?.lineIdentifier
        let operatorName = lineIdentifier?.name
        let lineId = lineIdentifier?.id
        let platform = tflLeg.departurePoint?.platformName ?? firstStop?.platformName
        let instructions = tflLeg.instruction?.summary
        let disruption = tflLeg.disruption?.description

        return JourneyLeg(
            id: UUID().uuidString,
            mode: mode,
            origin: origin,
            destination: destination,
            departureTime: departureDate,
            arrivalTime: arrivalDate,
            duration: durationSeconds,
            operatorName: operatorName,
            serviceIdentifier: nil,
            platform: platform,
            instructions: instructions,
            lineId: lineId,
            disruption: disruption
        )
    }

    /// Map TfL mode string to TransportMode
    private func mapTfLMode(_ modeId: String) -> TransportMode {
        switch modeId.lowercased() {
        case "national-rail", "train":
            return .train
        case "bus":
            return .bus
        case "walking", "walk":
            return .walk
        case "tube", "underground":
            return .tube
        case "dlr":
            return .dlr
        case "overground":
            return .overground
        case "tram":
            return .tram
        case "cable-car":
            return .cableCar
        case "river-bus", "river":
            return .river
        case "coach":
            return .coach
        case "cycle":
            return .cycle
        default:
            return .unknown
        }
    }

    /// Extract CRS code from TfL station ID (if present)
    /// TfL IDs like "910GGATWKAC" might contain station codes
    private func extractCRSFromStopId(_ stopId: String?) -> String? {
        // TfL station IDs don't reliably contain CRS codes
        // This would need station lookup - return nil for now
        return nil
    }

    /// Parse ISO8601 date string.
    /// TfL Journey API returns bare local-time strings ("2026-02-19T10:53:00") with no timezone
    /// suffix. The Arrivals API returns UTC with "Z". Both formats are handled here.
    private func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        // RFC3339 with fractional seconds and timezone (e.g. Arrivals API)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }

        // RFC3339 with timezone but no fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }

        // TfL Journey API: bare datetime, no timezone ("2026-02-19T10:53:00")
        // UK is GMT in winter / BST (+01:00) in summer. Use London timezone.
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        if let date = formatter.date(from: dateString) { return date }

        // Last resort: bare datetime interpreted as UTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString)
    }
}

extension TransportAPIJourneyResponse {
    /// Map TransportAPI response to Journey models
    func mapToJourneys(departureDate: Date) -> [Journey] {
        routes.compactMap { mapTransportAPIRoute($0, baseDate: departureDate) }
    }

    private func mapTransportAPIRoute(_ route: TransportAPIRoute, baseDate: Date) -> Journey? {
        // Parse times with base date (TransportAPI format: "HH:mm")
        guard let departureTime = parseTime(route.departureTime, baseDate: baseDate),
              let arrivalTime = parseTime(route.arrivalTime, baseDate: baseDate) else {
            return nil
        }

        // Map route parts to legs
        let legs = route.routeParts.compactMap { mapTransportAPIRoutePart($0, baseDate: baseDate) }
        guard !legs.isEmpty else { return nil }

        // Parse duration (format varies: "1:23" or "83 minutes")
        let durationSeconds = parseDuration(route.duration) ?? arrivalTime.timeIntervalSince(departureTime)

        return Journey(
            id: UUID().uuidString,
            legs: legs,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            duration: durationSeconds
        )
    }

    private func mapTransportAPIRoutePart(_ part: TransportAPIRoutePart, baseDate: Date) -> JourneyLeg? {
        // Map mode first to check if it's walking (no times required)
        let mode = mapTransportAPIMode(part.mode)

        // For walking legs, times might be optional
        if mode == .walk {
            return mapWalkingLeg(part, baseDate: baseDate)
        }

        // Parse times for transit legs
        guard let deptTimeStr = part.departureTime,
              let arrTimeStr = part.arrivalTime,
              let departureTime = parseTime(deptTimeStr, baseDate: baseDate),
              let arrivalTime = parseTime(arrTimeStr, baseDate: baseDate) else {
            return nil
        }

        // Create locations
        let origin = JourneyLocation(
            name: part.fromStationName ?? "Unknown",
            crs: part.fromStationCode,
            latitude: nil,
            longitude: nil,
            stopId: nil
        )

        let destination = JourneyLocation(
            name: part.toStationName ?? "Unknown",
            crs: part.toStationCode,
            latitude: nil,
            longitude: nil,
            stopId: nil
        )

        let durationSeconds = arrivalTime.timeIntervalSince(departureTime)

        return JourneyLeg(
            id: UUID().uuidString,
            mode: mode,
            origin: origin,
            destination: destination,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            duration: durationSeconds,
            operatorName: part.operatorName,
            serviceIdentifier: part.serviceTimetable?.id,
            platform: part.platform,
            instructions: nil,
            lineId: nil,
            disruption: nil
        )
    }

    private func mapWalkingLeg(_ part: TransportAPIRoutePart, baseDate: Date) -> JourneyLeg? {
        // Walking legs use estimated times or current time
        let departureTime = part.departureTime.flatMap { parseTime($0, baseDate: baseDate) } ?? baseDate
        let arrivalTime = part.arrivalTime.flatMap { parseTime($0, baseDate: baseDate) } ?? departureTime.addingTimeInterval(300) // Default 5 min

        let origin = JourneyLocation(
            name: part.fromStationName ?? "Walk",
            crs: part.fromStationCode,
            latitude: nil,
            longitude: nil,
            stopId: nil
        )

        let destination = JourneyLocation(
            name: part.toStationName ?? "Destination",
            crs: part.toStationCode,
            latitude: nil,
            longitude: nil,
            stopId: nil
        )

        return JourneyLeg(
            id: UUID().uuidString,
            mode: .walk,
            origin: origin,
            destination: destination,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            duration: arrivalTime.timeIntervalSince(departureTime),
            operatorName: nil,
            serviceIdentifier: nil,
            platform: nil,
            instructions: "Walk to \(destination.name)",
            lineId: nil,
            disruption: nil
        )
    }

    /// Parse time string (HH:mm) and combine with base date
    private func parseTime(_ timeString: String, baseDate: Date) -> Date? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone.current

        guard let timeOnly = timeFormatter.date(from: timeString) else {
            return nil
        }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)
        let baseComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)

        var combinedComponents = DateComponents()
        combinedComponents.year = baseComponents.year
        combinedComponents.month = baseComponents.month
        combinedComponents.day = baseComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute

        return calendar.date(from: combinedComponents)
    }

    private func mapTransportAPIMode(_ modeString: String) -> TransportMode {
        switch modeString.lowercased() {
        case "train":
            return .train
        case "bus":
            return .bus
        case "walk", "walking":
            return .walk
        case "tube", "underground":
            return .tube
        default:
            return .unknown
        }
    }

    private func parseDuration(_ durationString: String) -> TimeInterval? {
        // Try "1:23" format (hours:minutes)
        let components = durationString.components(separatedBy: ":")
        if components.count == 2,
           let hours = Int(components[0]),
           let minutes = Int(components[1]) {
            return TimeInterval(hours * 3600 + minutes * 60)
        }

        // Try "83 minutes" format
        if let minutes = Int(durationString.components(separatedBy: " ").first ?? "") {
            return TimeInterval(minutes * 60)
        }

        return nil
    }
}
