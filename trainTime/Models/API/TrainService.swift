//
//  TrainService.swift
//  trainTime
//
//  Single service in a departure board response
//

import Foundation

struct TrainService: Codable, Identifiable, Hashable {
    static func == (lhs: TrainService, rhs: TrainService) -> Bool {
        lhs.serviceID == rhs.serviceID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(serviceID)
    }

    let origin: [ServiceLocation]?
    let destination: [ServiceLocation]?
    let sta: String?  // scheduled arrival
    let eta: String?  // estimated arrival
    let std: String?  // scheduled departure
    let etd: String?  // estimated departure
    let platform: String?
    let operatorName: String?  // named 'operator' in JSON but reserved in Swift
    let operatorCode: String?
    let isCancelled: Bool?
    let cancelReason: String?
    let delayReason: String?
    let serviceID: String?
    let length: Int?
    let isCircularRoute: Bool?

    var id: String { serviceID ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case origin, destination, sta, eta, std, etd, platform
        case operatorName = "operator"
        case operatorCode, isCancelled, cancelReason, delayReason
        case serviceID = "serviceIdUrlSafe"
        case length, isCircularRoute
    }

    /// Display-friendly departure time
    var departureTime: String {
        TrainTimeFormatter.displayTime(std)
    }

    /// Status for this service
    var status: ServiceStatus {
        if isCancelled == true { return .cancelled }
        guard let etd else { return .onTime }
        if etd == "On time" { return .onTime }
        if etd == "Cancelled" { return .cancelled }
        if etd == "Delayed" { return .delayed }
        if let delay = TrainTimeFormatter.delayMinutes(scheduled: std, actual: etd), delay > 0 {
            return .delayed
        }
        return .onTime
    }

    /// Estimated or scheduled departure for display
    var expectedDeparture: String {
        if let etd, etd != "On time" && etd != "Cancelled" && etd != "Delayed" {
            return TrainTimeFormatter.displayTime(etd)
        }
        return departureTime
    }

    /// Destination name for display
    var destinationName: String {
        destination?.first?.locationName ?? "Unknown"
    }

    /// Origin name for display
    var originName: String {
        origin?.first?.locationName ?? "Unknown"
    }
}

enum ServiceStatus: String {
    case onTime
    case delayed
    case cancelled

    var displayText: String {
        switch self {
        case .onTime: return String(localized: "On time")
        case .delayed: return String(localized: "Delayed")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
}
