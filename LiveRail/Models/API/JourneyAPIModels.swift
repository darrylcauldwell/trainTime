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
    let startDateTime: String
    let duration: Int // in minutes
    let arrivalDateTime: String
    let legs: [TfLLeg]

    enum CodingKeys: String, CodingKey {
        case startDateTime, duration, arrivalDateTime, legs
    }
}

struct TfLLeg: Codable {
    let mode: TfLMode
    let departureTime: String
    let arrivalTime: String
    let duration: Int // in minutes
    let instruction: TfLInstruction?
    let disruption: TfLDisruption?
    let path: TfLPath?
    let routeOptions: [TfLRouteOption]?

    enum CodingKeys: String, CodingKey {
        case mode, departureTime, arrivalTime, duration
        case instruction, disruption, path, routeOptions
    }
}

struct TfLMode: Codable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct TfLInstruction: Codable {
    let summary: String
    let detailed: String?

    enum CodingKeys: String, CodingKey {
        case summary, detailed
    }
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
    let name: String
    let lat: Double
    let lon: Double
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
    let id: String
    let name: String
    let modeName: String?
    let operatorId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, modeName, operatorId
    }
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
        // Parse dates
        guard let departureDate = parseISO8601(tflJourney.startDateTime),
              let arrivalDate = parseISO8601(tflJourney.arrivalDateTime) else {
            return nil
        }

        // Map legs
        let mappedLegs = tflJourney.legs.compactMap { mapTfLLeg($0) }
        guard !mappedLegs.isEmpty else { return nil }

        // Generate journey ID
        let journeyId = UUID().uuidString

        // Calculate duration in seconds
        let durationSeconds = TimeInterval(tflJourney.duration * 60)

        return Journey(
            id: journeyId,
            legs: mappedLegs,
            departureTime: departureDate,
            arrivalTime: arrivalDate,
            duration: durationSeconds
        )
    }

    private func mapTfLLeg(_ tflLeg: TfLLeg) -> JourneyLeg? {
        // Parse times
        guard let departureDate = parseISO8601(tflLeg.departureTime),
              let arrivalDate = parseISO8601(tflLeg.arrivalTime) else {
            return nil
        }

        // Map transport mode
        let mode = mapTfLMode(tflLeg.mode.id)

        // Extract origin/destination from path stopPoints
        guard let stopPoints = tflLeg.path?.stopPoints,
              let firstStop = stopPoints.first,
              let lastStop = stopPoints.last else {
            return nil
        }

        let origin = JourneyLocation(
            name: firstStop.name,
            crs: extractCRSFromStopId(firstStop.id),
            latitude: firstStop.lat,
            longitude: firstStop.lon
        )

        let destination = JourneyLocation(
            name: lastStop.name,
            crs: extractCRSFromStopId(lastStop.id),
            latitude: lastStop.lat,
            longitude: lastStop.lon
        )

        // Extract operator and service ID from routeOptions
        let operatorName = tflLeg.routeOptions?.first?.lineIdentifier?.name
        let serviceIdentifier: String? = nil // TfL doesn't provide compatible service IDs for Huxley

        // Platform from first stop
        let platform = firstStop.platformName

        // Instructions for walking legs
        let instructions = mode == .walk ? tflLeg.instruction?.summary : nil

        // Duration in seconds
        let durationSeconds = TimeInterval(tflLeg.duration * 60)

        return JourneyLeg(
            id: UUID().uuidString,
            mode: mode,
            origin: origin,
            destination: destination,
            departureTime: departureDate,
            arrivalTime: arrivalDate,
            duration: durationSeconds,
            operatorName: operatorName,
            serviceIdentifier: serviceIdentifier,
            platform: platform,
            instructions: instructions
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

    /// Parse ISO8601 date string
    private func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
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
            longitude: nil
        )

        let destination = JourneyLocation(
            name: part.toStationName ?? "Unknown",
            crs: part.toStationCode,
            latitude: nil,
            longitude: nil
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
            instructions: nil
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
            longitude: nil
        )

        let destination = JourneyLocation(
            name: part.toStationName ?? "Destination",
            crs: part.toStationCode,
            latitude: nil,
            longitude: nil
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
            instructions: "Walk to \(destination.name)"
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
