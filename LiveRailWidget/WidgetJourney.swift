//
//  WidgetJourney.swift
//  trainTimeWidget
//
//  Lightweight Codable struct for App Group data transfer
//

import Foundation

struct WidgetJourney: Codable {
    let originCRS: String
    let originName: String
    let destinationCRS: String
    let destinationName: String

    static let appGroupID = "group.com.darrylcauldwell.trainTime"
    static let userDefaultsKey = "widgetJourney"

    static func load() -> WidgetJourney? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetJourney.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
