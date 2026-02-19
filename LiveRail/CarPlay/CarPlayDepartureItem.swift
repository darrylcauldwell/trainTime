//
//  CarPlayDepartureItem.swift
//  LiveRail
//
//  Helper to build CPListItem from TrainService
//

import CarPlay

enum CarPlayDepartureItem {
    static func listItem(from service: TrainService) -> CPListItem {
        let scheduled = service.std ?? service.departureTime

        // Build time string: show estimated alongside scheduled when delayed
        let timeText: String
        if service.status == .delayed, let eta = service.etd, eta != scheduled, eta != "On time" {
            timeText = "\(scheduled) → \(eta)"
        } else {
            timeText = scheduled
        }

        let title = "\(timeText)  \(service.destinationName)"

        // Build detail: status + platform
        var detailParts: [String] = []
        switch service.status {
        case .onTime:
            detailParts.append("On time")
        case .delayed:
            if let eta = service.etd, eta != "On time" {
                detailParts.append("Delayed – exp. \(eta)")
            } else {
                detailParts.append("Delayed")
            }
        case .cancelled:
            detailParts.append("Cancelled")
        }
        if let platform = service.platform {
            detailParts.append("Platform \(platform)")
        }

        let item = CPListItem(text: title, detailText: detailParts.joined(separator: "  ·  "))
        return item
    }
}
