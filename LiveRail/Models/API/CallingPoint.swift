//
//  CallingPoint.swift
//  LiveRail
//
//  Single calling point with scheduled, estimated, and actual times
//

import Foundation

struct CallingPoint: Codable, Identifiable {
    let locationName: String?
    let crs: String?
    let st: String?  // scheduled time
    let et: String?  // estimated time ("On time", "HH:mm", "Cancelled", "Delayed")
    let at: String?  // actual time (once departed/arrived)
    let isCancelled: Bool?
    let length: Int?
    let detachFront: Bool?

    // Stable ID: CRS + scheduled time should be unique per service
    var id: String { "\(crs ?? "unknown")_\(st ?? "notime")" }

    /// Whether this point has been passed (has actual time)
    var hasDeparted: Bool {
        at != nil && at != ""
    }

    /// Best available time for display
    var displayTime: String {
        if let at, !at.isEmpty { return TrainTimeFormatter.displayTime(at) }
        if let et, et != "On time", et != "Cancelled", et != "Delayed", !et.isEmpty {
            return TrainTimeFormatter.displayTime(et)
        }
        return TrainTimeFormatter.displayTime(st)
    }

    /// Status text for display
    var statusText: String {
        if isCancelled == true || et == "Cancelled" { return String(localized: "Cancelled") }
        if let at, !at.isEmpty { return String(localized: "Departed") }
        if let et {
            if et == "On time" { return String(localized: "On time") }
            if et == "Delayed" { return String(localized: "Delayed") }
            if let delay = TrainTimeFormatter.delayMinutes(scheduled: st, actual: et), delay > 0 {
                return "Exp \(TrainTimeFormatter.displayTime(et))"
            }
            return String(localized: "On time")
        }
        return ""
    }
}

struct CallingPointList: Codable {
    let callingPoint: [CallingPoint]?
}
