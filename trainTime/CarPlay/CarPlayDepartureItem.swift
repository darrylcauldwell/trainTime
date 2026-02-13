//
//  CarPlayDepartureItem.swift
//  trainTime
//
//  Helper to build CPListItem from TrainService
//

import CarPlay

enum CarPlayDepartureItem {
    static func listItem(from service: TrainService) -> CPListItem {
        let time = service.departureTime
        let status = service.status.displayText
        let platform = service.platform.map { "P\($0)" } ?? ""

        let title = "\(time)  \(service.destinationName)"
        let detail = "\(status)  \(platform)"

        let item = CPListItem(text: title, detailText: detail)
        return item
    }
}
