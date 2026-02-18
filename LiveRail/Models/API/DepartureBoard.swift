//
//  DepartureBoard.swift
//  LiveRail
//
//  Huxley2 departure board response model
//

import Foundation

struct DepartureBoard: Codable {
    let generatedAt: String?
    let locationName: String?
    let crs: String?
    let filterLocationName: String?
    let filterCrs: String?
    let filteredServices: [TrainService]?  // used when filtering by destination
    let trainServices: [TrainService]?     // used when no filter
    let nrccMessages: [NRCCMessage]?

    /// Return filtered services if available, otherwise all train services
    var services: [TrainService] {
        filteredServices ?? trainServices ?? []
    }
}

struct NRCCMessage: Codable, Identifiable {
    let value: String?

    // Stable ID from content hash
    var id: Int { (value ?? "").hashValue }

    enum CodingKeys: String, CodingKey {
        case value
    }
}
