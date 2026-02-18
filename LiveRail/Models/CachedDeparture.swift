//
//  CachedDeparture.swift
//  LiveRail
//
//  SwiftData model for offline departure cache
//

import Foundation
import SwiftData

@Model
final class CachedDeparture {
    @Attribute(.unique) var cacheKey: String
    var jsonData: Data
    var fetchedAt: Date
    var originCRS: String
    var destinationCRS: String

    init(cacheKey: String, jsonData: Data, originCRS: String, destinationCRS: String) {
        self.cacheKey = cacheKey
        self.jsonData = jsonData
        self.fetchedAt = Date()
        self.originCRS = originCRS
        self.destinationCRS = destinationCRS
    }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 120
    }

    var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > 86400
    }
}
