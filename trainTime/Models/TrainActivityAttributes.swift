//
//  TrainActivityAttributes.swift
//  trainTime
//
//  ActivityAttributes for Live Activity on lock screen / Dynamic Island
//

import Foundation
import ActivityKit

struct TrainActivityAttributes: ActivityAttributes {
    // Fixed journey data
    let originName: String
    let originCRS: String
    let destinationName: String
    let destinationCRS: String
    let operatorName: String
    let serviceID: String

    struct ContentState: Codable, Hashable {
        let currentStation: String?
        let nextStop: String?
        let eta: String?
        let delayMinutes: Int
        let progress: Double // 0.0 to 1.0
        let platform: String?
        let isArrived: Bool
    }
}
