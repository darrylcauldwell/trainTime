//
//  CachedJourney.swift
//  LiveRail
//
//  SwiftData model for offline journey cache
//

import Foundation
import SwiftData

@Model
final class CachedJourney {
    @Attribute(.unique) var cacheKey: String
    var jsonData: Data
    var fetchedAt: Date
    var originCRS: String
    var destinationCRS: String
    var departureTime: Date

    init(cacheKey: String, jsonData: Data, originCRS: String, destinationCRS: String, departureTime: Date) {
        self.cacheKey = cacheKey
        self.jsonData = jsonData
        self.fetchedAt = Date()
        self.originCRS = originCRS
        self.destinationCRS = destinationCRS
        self.departureTime = departureTime
    }

    /// Cache is stale after 5 minutes
    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 300 // 5 minutes
    }

    /// Cache expires after 1 hour
    var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > 3600 // 1 hour
    }
}
