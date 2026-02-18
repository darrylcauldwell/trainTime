//
//  ServiceLocation.swift
//  LiveRail
//
//  Origin/destination location in a Huxley2 service response
//

import Foundation

struct ServiceLocation: Codable, Identifiable, Hashable {
    let locationName: String?
    let crs: String?
    let via: String?
    let futureChangeTo: String?

    // Stable ID derived from content, not random UUID
    var id: String { crs ?? locationName ?? "unknown" }
}
