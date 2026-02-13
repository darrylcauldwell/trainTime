//
//  CachedServiceDetail.swift
//  trainTime
//
//  SwiftData model for offline service detail cache
//

import Foundation
import SwiftData

@Model
final class CachedServiceDetail {
    @Attribute(.unique) var serviceID: String
    var jsonData: Data
    var fetchedAt: Date

    init(serviceID: String, jsonData: Data) {
        self.serviceID = serviceID
        self.jsonData = jsonData
        self.fetchedAt = Date()
    }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 60
    }

    var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > 86400
    }
}
