//
//  RecentRoute.swift
//  trainTime
//
//  SwiftData model for recently searched routes
//

import Foundation
import SwiftData

@Model
final class RecentRoute {
    var originCRS: String
    var originName: String
    var destinationCRS: String
    var destinationName: String
    var searchedAt: Date
    @Attribute(.unique) var routeKey: String

    init(originCRS: String, originName: String, destinationCRS: String, destinationName: String) {
        self.originCRS = originCRS
        self.originName = originName
        self.destinationCRS = destinationCRS
        self.destinationName = destinationName
        self.searchedAt = Date()
        self.routeKey = "\(originCRS)-\(destinationCRS)"
    }
}
