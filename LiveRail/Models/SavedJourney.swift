//
//  SavedJourney.swift
//  LiveRail
//
//  SwiftData model for favourite route pairs
//

import Foundation
import SwiftData

@Model
final class SavedJourney {
    var originCRS: String
    var originName: String
    var destinationCRS: String
    var destinationName: String
    var createdAt: Date

    init(originCRS: String, originName: String, destinationCRS: String, destinationName: String) {
        self.originCRS = originCRS
        self.originName = originName
        self.destinationCRS = destinationCRS
        self.destinationName = destinationName
        self.createdAt = Date()
    }
}
